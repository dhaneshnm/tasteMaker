# 421 of the 1,694 paintings holding museum text stored it as HTML — Cleveland's
# <em>/<i> title italics, Minneapolis's Google Docs paste-ups — and the wall
# label renders `description` escaped, so a reader on dailytondo.com was shown a
# literal "<em>The Beggar's Dessert</em>". `Painting.plain_text` closes the door
# for every future write; this closes it for the rows already through it.
#
# A migration rather than a rake task because prod's `bin/docker-entrypoint`
# runs `db:prepare` on deploy: this is the only backfill mechanism that reaches
# the live database without a hand-run console session.
#
# Calls the model on purpose. Copying the regex here is how `db/seeds.rb` came
# to carry its own stale copy of the AIC User-Agent and 403 every image in
# production (SHIPLOG 2026-08-14) — one implementation, or none.
class FlattenMuseumHtmlInPaintingDescriptions < ActiveRecord::Migration[8.1]
  def up
    Painting.reset_column_information

    scope = Painting.where("description LIKE ? OR description LIKE ?", "%<%", "%&%")
    changed = 0

    scope.find_each do |painting|
      plain = Painting.plain_text(painting.description)
      next if plain == painting.description

      # update_column, not update!: these rows are already valid and a painting
      # whose image went missing since seeding must not block the text fix.
      painting.update_column(:description, plain)
      changed += 1
    end

    say "flattened #{changed} museum descriptions"
  end

  def down
    # The tags are gone, not stashed. Nothing to put back.
    raise ActiveRecord::IrreversibleMigration
  end
end
