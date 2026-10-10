# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = false
  def show? = false
  def create? = false
  def new? = create?
  def update? = false
  def edit? = update?
  def destroy? = false

  private

  def admin? = user&.admin? || false
  def staff? = user&.staff? || false
  def owner? = record.respond_to?(:user) && record.user == user

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve = raise(NotImplementedError, "You must define #resolve in #{self.class}")

    private

    attr_reader :user, :scope
  end
end
