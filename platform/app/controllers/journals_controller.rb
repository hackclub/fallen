class JournalsController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized
  before_action :set_project, only: :create
  before_action :set_journal, only: %i[update destroy]

  def create
    journal = @project.journals.build(journal_params.merge(user: current_user, source: "web"))
    authorize journal

    if journal.save
      SyncJournalToSlackJob.perform_later(journal, "create")
      redirect_to project_path(@project), notice: "Journal logged."
    else
      inertia_errors(journal, fallback_location: project_path(@project))
    end
  end

  def update
    authorize @journal

    if @journal.update(journal_params)
      SyncJournalToSlackJob.perform_later(@journal, "update")
      redirect_to project_path(@journal.project), notice: "Journal updated."
    else
      inertia_errors(@journal, fallback_location: project_path(@journal.project))
    end
  end

  def destroy
    authorize @journal
    @journal.discard
    SyncJournalToSlackJob.perform_later(@journal, "delete")
    redirect_to project_path(@journal.project), notice: "Journal deleted."
  end

  private

  def set_project
    @project = Project.kept.find_by_public_id!(params[:project_id])
  end

  def set_journal
    @journal = Journal.kept.find_by_public_id!(params[:id])
  end

  # `images` is the full list of blob signed ids (direct uploads) the journal should end up with.
  # `lapse_timelapse` is the public id of one of the person's timelapses, or blank for none.
  def journal_params
    permitted = params.expect(journal: [ :body, :duration, :lapse_timelapse, images: [] ])
    permitted.to_h.symbolize_keys.tap do |h|
      h[:images] = Array(h[:images]).compact_blank
      h[:lapse_timelapse] = h[:lapse_timelapse].presence && current_user.lapse_timelapses.find_by_public_id!(h[:lapse_timelapse]) if h.key?(:lapse_timelapse)
    end
  end
end
