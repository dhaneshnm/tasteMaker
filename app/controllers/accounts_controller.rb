# The exit door (story 0015). One action: a signed-in reader deletes their
# account and every work it kept. No soft delete, no grace period, no email —
# there is no mailer and nothing to mail. The confirm dialog on the collection
# page names what this destroys before it runs.
class AccountsController < ApplicationController
  def destroy
    # The wall passes devices too; this door is account-only. A device POSTing
    # here (there is no UI path) just goes home.
    return redirect_to(root_path, status: :see_other) unless current_user

    current_user.destroy
    reset_session
    redirect_to root_path, status: :see_other
  end
end
