# Story 0017 Release 2. Two columns, one per identity, both for the claim.
class AddHandoffAndClaimToIdentities < ActiveRecord::Migration[8.1]
  def change
    # The handoff token's single-use counter (`User.generates_token_for`). The
    # token embeds this value; consuming it increments the column, which
    # invalidates the token by making the payload disagree with the record.
    #
    # A counter and not a table: Rails signs and expires the token itself, so
    # there is nothing to store and nothing to sweep. The earlier plan specified
    # a `handoff_tokens` table on the grounds that a cache-backed replay guard
    # no-ops under `:null_store` in test — true of `MessageVerifier` plus a
    # cache, and not true of this, which touches neither.
    add_column :users, :handoff_seq, :integer, null: false, default: 0

    # When this device last handed its kept works to an account.
    #
    # It exists for one sentence on one screen: a reader who signs in, moves
    # their collection, then signs out sees an EMPTY `/collection`, and the
    # first-day copy there ("The works you keep will gather here") reads as
    # loss. This column is what lets that screen say where they went instead.
    # Nullable on purpose — most devices never claim, and "never" is a real
    # answer rather than a zero.
    add_column :devices, :claimed_at, :datetime
  end
end
