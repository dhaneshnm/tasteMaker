require "csv"
require "json"
require "net/http"
require "open-uri"

# One fetcher per museum. Each returns Pool::Candidate objects and knows nothing
# about curation.
#
# All four use bulk or paged endpoints — the whole mirror is one 300 MB CSV plus
# roughly 60 API requests. Crawling object-by-object would take a day against
# AIC's 60 req/min; that is what bulk endpoints exist to avoid.
module Pool
  module Sources
    # No email address in here: the Art Institute sits behind Cloudflare, which
    # 403s a User-Agent containing one. Everything else about this string is
    # fine — it was the contact address alone that got the mirror blocked.
    USER_AGENT = "Tondo/1.0 (daily-art app, CC0 museum images)"

    # git-LFS: raw.githubusercontent.com serves a 130-byte pointer file for this
    # path. media.githubusercontent.com serves the actual CSV.
    MET_CSV_URL = "https://media.githubusercontent.com/media/metmuseum/openaccess/master/MetObjects.csv".freeze
    MET_OBJECT_URL = "https://collectionapi.metmuseum.org/public/collection/v1/objects/%d".freeze
    AIC_URL = "https://api.artic.edu/api/v1/artworks/search".freeze
    AIC_IIIF = "https://www.artic.edu/iiif/2/%s/full/%d,/0/default.jpg".freeze
    CMA_URL = "https://openaccess-api.clevelandart.org/api/artworks/".freeze
    MIA_URL = "https://search.artsmia.org/classification:Paintings".freeze

    module_function

    def all = { "met" => method(:met), "aic" => method(:aic), "cma" => method(:cma), "mia" => method(:mia) }

    # --- Met ------------------------------------------------------------
    #
    # The CSV carries no image URL and no dimensions, and public domain does not
    # guarantee a photograph exists. Both are resolved per selected work in
    # `resolve_met_image`, so the mirror stays one download instead of 5,578
    # API calls for works we will not pick.
    def met(csv_path: nil)
      path = csv_path || download_met_csv
      out = []
      CSV.foreach(path, headers: true) do |row|
        next unless row["Is Public Domain"] == "True"
        next unless row["Classification"].to_s.match?(/painting/i)
        next if row["Title"].to_s.strip.empty?

        out << Candidate.new(
          source: "met", source_id: row["Object ID"].to_i,
          title: row["Title"].to_s.strip,
          artist: row["Artist Display Name"].to_s.strip,
          life_date: row["Artist Display Bio"].to_s.strip,
          dated: row["Object Date"].to_s.strip,
          year: Pool.year_from(row["Object Date"], row["Object End Date"]),
          medium: row["Medium"].to_s.strip,
          dimension: row["Dimensions"].to_s.strip,
          country: row["Country"].to_s.strip,
          culture: row["Culture"].to_s.strip,
          department: row["Department"].to_s.strip,
          region: Pool.region_for(country: row["Country"], culture: [ row["Culture"], row["Period"], row["Region"] ].join(" "),
                                  department: row["Department"]),
          description: nil, # The Met publishes no curatorial text. See plan F1.
          creditline: row["Credit Line"].to_s.strip,
          accession_number: row["Object Number"].to_s.strip,
          image_license: "Public Domain",
          highlight: row["Is Highlight"] == "True"
        )
      end
      out
    end

    def download_met_csv
      path = MIRROR_DIR.join("MetObjects.csv")
      return path if path.exist? && path.size > 100.megabytes

      MIRROR_DIR.mkpath
      warn "  downloading Met CSV (~300 MB, git-LFS)…"
      URI.parse(MET_CSV_URL).open("User-Agent" => USER_AGENT, read_timeout: 600) do |io|
        IO.copy_stream(io, path.to_s)
      end
      path
    end

    # Fills in the image URL and its real dimensions for one selected Met work.
    # Returns false when the Met holds no photograph, or one too small for
    # Better bar 7 — the caller tops up from the next candidate.
    def resolve_met_image(candidate)
      body = get_json(format(MET_OBJECT_URL, candidate.source_id))
      url = body&.dig("primaryImage").presence
      return false if url.nil?

      width, height = Jpeg.remote_dimensions(url)
      return false if width.nil? || [ width, height ].max < MIN_EDGE

      candidate.image_url_full = url
      candidate.image_url_800 = body["primaryImageSmall"].presence || url
      candidate.image_width = width
      candidate.image_height = height
      true
    end

    # --- Art Institute of Chicago ---------------------------------------
    #
    # AIC refuses any request past the thousandth result — `limit * page > 1000`
    # is a 403, not an empty page — so 1,954 paintings cannot be paged straight
    # through. The collection is sliced by date instead, each slice split until
    # it fits under the ceiling, plus one slice for works AIC gives no date.
    AIC_FIELDS = %w[id title artist_title artist_display date_display date_end medium_display
                    dimensions place_of_origin department_title description short_description
                    credit_line main_reference_number image_id is_boosted].freeze
    AIC_MAX_RESULTS = 1_000

    def aic
      slices = [ [ -4000, 1500 ], [ 1501, 1800 ], [ 1801, 1900 ], [ 1901, 2100 ] ]
      rows = slices.flat_map { |from, to| aic_slice(from, to) } + aic_undated
      rows.uniq { |r| r["id"] }.filter_map { |r| aic_candidate(r) }
    end

    # Splits a date range in half until AIC will serve the whole of it.
    def aic_slice(from, to, depth: 0)
      query = aic_query.merge(
        "query[bool][must][2][range][date_end][gte]" => from,
        "query[bool][must][2][range][date_end][lte]" => to
      )
      total = get_json(AIC_URL, query.merge("limit" => 1, "fields" => "id"))&.dig("pagination", "total").to_i
      return [] if total.zero?

      if total > AIC_MAX_RESULTS && depth < 8 && to > from
        middle = from + ((to - from) / 2)
        return aic_slice(from, middle, depth: depth + 1) + aic_slice(middle + 1, to, depth: depth + 1)
      end

      aic_pages(query)
    end

    def aic_undated
      aic_pages(aic_query.merge("query[bool][must_not][0][exists][field]" => "date_end"))
    end

    def aic_pages(query)
      out = []
      page = 1
      loop do
        body = get_json(AIC_URL, query.merge("fields" => AIC_FIELDS.join(","), "limit" => 100, "page" => page))
        rows = body&.dig("data") || []
        out.concat(rows)
        break if rows.size < 100 || (page * 100) >= AIC_MAX_RESULTS

        page += 1
      end
      out
    end

    def aic_query
      {
        "query[bool][must][0][term][is_public_domain]" => "true",
        "query[bool][must][1][term][artwork_type_title.keyword]" => "Painting"
      }
    end

    def aic_candidate(r)
      return nil if r["image_id"].blank? || r["title"].blank?

      text = r["description"].presence || r["short_description"].presence
      Candidate.new(
        source: "aic", source_id: r["id"].to_i,
        title: r["title"].to_s.strip,
        artist: r["artist_title"].to_s.strip,
        life_date: r["artist_display"].to_s.split("\n").last.to_s.strip,
        dated: r["date_display"].to_s.strip,
        year: Pool.year_from(r["date_display"], r["date_end"]),
        medium: r["medium_display"].to_s.strip,
        dimension: r["dimensions"].to_s.strip,
        country: r["place_of_origin"].to_s.strip,
        culture: r["place_of_origin"].to_s.strip,
        department: r["department_title"].to_s.strip,
        region: Pool.region_for(country: r["place_of_origin"], culture: nil, department: r["department_title"]),
        # HTML, like Cleveland's and Minneapolis's — and until 2026-08-15 this
        # was the only adapter that flattened it, which is exactly how the other
        # two shipped literal "<em>" to the page. One shared call now, so bar 6
        # counts characters a reader can read rather than markup.
        description: Painting.plain_text(text),
        creditline: r["credit_line"].to_s.strip,
        accession_number: r["main_reference_number"].to_s.strip,
        # IIIF, requested at the size we want rather than downloaded full and
        # shrunk: nothing from AIC is resized on ingest.
        image_url_full: format(AIC_IIIF, r["image_id"], 1686),
        image_url_800: format(AIC_IIIF, r["image_id"], 843),
        image_width: 1686, image_height: 1686,
        image_license: "CC0",
        highlight: !!r["is_boosted"]
      )
    end

    # --- Cleveland ------------------------------------------------------
    def cma
      out = []
      skip = 0
      loop do
        body = get_json(CMA_URL, { "cc0" => 1, "has_image" => 1, "type" => "Painting", "limit" => 1000, "skip" => skip })
        rows = body&.dig("data") || []
        break if rows.empty?

        rows.each do |r|
          # `web` is never 1600px wide (0 of 20 sampled); `print` is 3400px.
          print_image = r.dig("images", "print") || r.dig("images", "full")
          next if print_image.nil? || r["title"].blank?

          creator = r["creators"]&.first
          out << Candidate.new(
            source: "cma", source_id: r["id"].to_i,
            title: r["title"].to_s.strip,
            artist: creator&.dig("description").to_s.sub(/\s*\(.*\)\s*\z/, "").strip,
            life_date: creator&.dig("biography").presence || creator&.dig("description").to_s[/\(([^)]*)\)/, 1],
            dated: r["creation_date"].to_s.strip,
            year: Pool.year_from(r["creation_date"], r["creation_date_latest"]),
            medium: r["technique"].to_s.strip,
            dimension: r.dig("measurements").to_s.strip,
            country: Array(r["culture"]).join(", "),
            culture: Array(r["culture"]).join(", "),
            department: r["department"].to_s.strip,
            region: Pool.region_for(country: Array(r["culture"]).join(" "), culture: nil, department: r["department"]),
            description: Painting.plain_text(r["description"].presence || r["wall_description"].presence),
            creditline: r["creditline"].to_s.strip,
            accession_number: r["accession_number"].to_s.strip,
            image_url_full: print_image["url"],
            image_url_800: r.dig("images", "web", "url") || print_image["url"],
            image_width: print_image["width"].to_i, image_height: print_image["height"].to_i,
            image_license: r["share_license_status"].presence || "CC0",
            # Cleveland publishes no highlight flag. Counting these as ordinary
            # works understates the famous share rather than overstating it.
            highlight: false
          )
        end
        skip += rows.size
        break if skip > 20_000
      end
      out
    end

    # --- Minneapolis ----------------------------------------------------
    #
    # The only source whose image rights vary per object, and it says so per
    # object. Nothing here is assumed from the metadata licence.
    def mia
      out = []
      from = 0
      loop do
        body = get_json(MIA_URL, { "size" => 100, "from" => from })
        rows = body&.dig("hits", "hits") || []
        break if rows.empty?

        rows.each do |hit|
          r = hit["_source"]
          next unless r["image"] == "valid" && r["public_access"].to_i == 1
          next unless r["rights_type"].to_s.casecmp("public domain").zero?
          next unless r["Rights_Image_Display"].to_s.casecmp("full").zero?
          next if r["title"].blank?

          id = r["id"].to_i
          full = mia_image_url(r, "full")
          next if full.nil?

          out << Candidate.new(
            source: "mia", source_id: id,
            title: r["title"].to_s.strip,
            artist: r["artist"].to_s.sub(/\A(attributed to|after|workshop of)\s+/i, "").strip,
            life_date: r["life_date"].to_s.strip,
            dated: r["dated"].to_s.strip,
            year: Pool.year_from(r["dated"]),
            medium: r["medium"].to_s.strip,
            dimension: r["dimension"].to_s.strip,
            country: r["country"].to_s.strip,
            culture: r["culture"].to_s.strip,
            department: r["department"].to_s.strip,
            region: Pool.region_for(country: r["country"], culture: r["culture"],
                                    department: r["department"], continent: r["continent"]),
            description: Painting.plain_text(r["text"]),
            creditline: r["creditline"].to_s.strip,
            accession_number: r["accession_number"].to_s.strip,
            image_url_full: full,
            image_url_800: mia_image_url(r, "800"),
            image_width: r["image_width"].to_i, image_height: r["image_height"].to_i,
            image_license: r["rights_type"].to_s.strip,
            highlight: r["highlights"].to_i == 1
          )
        end
        from += rows.size
        break if from > 10_000
      end
      out
    end

    # The image path cannot be derived from the object id: `img.artsmia.org`
    # shards on a cache key the record carries (`083000\600\40\83645`) and names
    # the file after the rendition, not the object (`mia_5014236.jpg`). Deriving
    # it from the id produced plausible URLs that every one of them 403'd.
    # The rendition stem is the whole basename, suffixes and all —
    # `mia_3003333_001.jpg` serves as `mia_3003333_001_full.jpg`. Matching only
    # the leading `mia_<digits>` dropped the `_001` and produced a 403 for every
    # work whose rendition carries one.
    def mia_image_url(record, size)
      location = record["Cache_Location"].to_s.tr("\\", "/")
      rendition = File.basename(record["Primary_RenditionNumber"].to_s, ".jpg").presence
      return nil if location.blank? || rendition.nil? || !rendition.start_with?("mia_")

      "https://img.artsmia.org/web_objects_cache/#{location}/#{rendition}_#{size}.jpg"
    end

    # Spot-checks that the plates a manifest points at actually exist.
    #
    # Minneapolis image paths cannot be derived from the object id, and deriving
    # them anyway produced 983 well-formed URLs that every one of them 403'd —
    # invisible until the download ran. Curation now proves a sample of each
    # museum's links before writing the manifest.
    def check_plates(candidates, per_source: 8)
      candidates.group_by(&:source).filter_map do |source, works|
        sample = works.each_slice([ works.size / per_source, 1 ].max).map(&:first).first(per_source)
        dead = sample.reject { |c| plate_reachable?(c.image_url_full) }
        next if dead.empty?

        "#{source}: #{dead.size} of #{sample.size} sampled plates unreachable (e.g. #{dead.first.image_url_full})"
      end
    end

    def plate_reachable?(url)
      return false if url.blank?

      uri = URI.parse(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 15, read_timeout: 30) do |http|
        # Some museum CDNs refuse HEAD; a one-byte ranged GET is answered by all four.
        http.get(uri.request_uri, { "User-Agent" => USER_AGENT, "Range" => "bytes=0-0" })
      end
      response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPPartialContent)
    rescue StandardError
      false
    end

    # --- HTTP -----------------------------------------------------------
    def get_json(url, params = nil, attempts: 3)
      uri = URI.parse(url)
      uri.query = URI.encode_www_form(params) if params

      attempts.times do |i|
        response = Net::HTTP.get_response(uri, { "User-Agent" => USER_AGENT, "AIC-User-Agent" => USER_AGENT })
        return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
        return nil if response.is_a?(Net::HTTPNotFound)

        sleep(2**i) # 429 and 5xx: back off rather than hammer a free API
      rescue StandardError => e
        raise if i == attempts - 1

        warn "  retrying #{uri.host}: #{e.message}"
        sleep(2**i)
      end
      nil
    end

    # Reads a JPEG's real dimensions from its header, over a ranged request, so
    # the Met's undocumented image sizes can be checked against Better bar 7
    # without downloading the whole plate.
    module Jpeg
      module_function

      def remote_dimensions(url, bytes: 256.kilobytes)
        uri = URI.parse(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 60) do |http|
          http.get(uri.request_uri, { "User-Agent" => USER_AGENT, "Range" => "bytes=0-#{bytes - 1}" })
        end
        return [ nil, nil ] unless response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPPartialContent)

        dimensions(response.body)
      rescue StandardError
        [ nil, nil ]
      end

      # Walks the JPEG marker chain to the frame header, which carries the size.
      def dimensions(data)
        return [ nil, nil ] unless data[0, 2] == "\xFF\xD8".b

        i = 2
        # The frame header is read through i+8, so that is what has to be there.
        while i + 8 < data.bytesize
          return [ nil, nil ] unless data.getbyte(i) == 0xFF

          marker = data.getbyte(i + 1)
          # SOF0-SOF15, excluding the four that are not frame headers.
          if marker.between?(0xC0, 0xCF) && ![ 0xC4, 0xC8, 0xCC ].include?(marker)
            height = data.getbyte(i + 5) << 8 | data.getbyte(i + 6)
            width  = data.getbyte(i + 7) << 8 | data.getbyte(i + 8)
            return [ width, height ]
          end
          i += 2 + (data.getbyte(i + 2) << 8 | data.getbyte(i + 3))
        end
        [ nil, nil ]
      end
    end
  end
end
