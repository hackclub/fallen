class Admin::FlagsController < Admin::ApplicationController
  skip_after_action :verify_policy_scoped # Flipper features are not records; the policy gates the whole page

  before_action :set_flag, only: %i[show update destroy]

  def index
    authorize [ :admin, :flag ]
    flags = FeatureFlag.all

    render inertia: "Admin/Flags/Index", props: {
      flags: AdminFlagSerializer.render(flags, users: users_for(flags)),
      groups: FeatureFlag::GROUPS
    }
  end

  def show
    render inertia: "Admin/Flags/Show", props: {
      flag: AdminFlagSerializer.render(@flag, users: users_for([ @flag ])),
      groups: FeatureFlag::GROUPS,
      # The people search for adding someone, loaded only when the field asks for it.
      user_matches: InertiaRails.optional { user_matches(params[:user_query]) }
    }
  end

  def create
    authorize [ :admin, :flag ]
    flag = FeatureFlag.new(params.expect(flag: [ :key ])[:key].to_s.strip)

    if flag.valid?(:create)
      flag.create!
      audit(flag, "create")
      redirect_to admin_flag_path(flag.key), notice: "Created #{flag.key}. It's off for everyone until you turn it on."
    else
      inertia_errors(flag, fallback_location: admin_flags_path)
    end
  end

  def update
    @flag.update!(**flag_params)
    audit(@flag, "update", flag_params)
    redirect_back_or_to admin_flag_path(@flag.key), notice: "#{@flag.key} is #{@flag.summary}."
  end

  def destroy
    @flag.destroy!
    audit(@flag, "destroy")
    redirect_to admin_flags_path, notice: "Deleted #{@flag.key}."
  end

  private

  def set_flag
    @flag = FeatureFlag.find!(params[:key])
    authorize [ :admin, :flag ], :"#{action_name}?"
  end

  def flag_params
    attrs = params.expect(flag: [ :everyone, :percentage_of_actors, :percentage_of_time, groups: [], actors: [] ]).to_h.symbolize_keys
    attrs[:everyone] = ActiveModel::Type::Boolean.new.cast(attrs[:everyone]) if attrs.key?(:everyone)
    attrs
  end

  def users_for(flags)
    User.where_public_ids(flags.flat_map(&:actors).uniq).index_by(&:public_id)
  end

  def user_matches(query)
    return [] if query.blank?

    users = User.kept.search(query).limit(8)
    users.map { |user| { id: user.public_id, name: user.display_name, avatar: user.avatar_url, email: user.email } }
  end

  # Flipper keeps no history, so every change is a log line naming the admin.
  def audit(flag, change, details = {})
    Rails.logger.info({ event: "flag.#{change}", admin_id: true_user.id, flag: flag.key, **details }.to_json)
  end
end
