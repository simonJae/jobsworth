require "test_helper"

class UserTest < ActiveRecord::TestCase
  fixtures :users, :projects, :project_permissions, :companies, :customers

  def setup
    @user = users(:admin)
  end
  subject { @user }


  should validate_presence_of(:company)
  should validate_presence_of(:password)
  should validate_presence_of(:username)
  should validate_presence_of(:name)

  should have_many(:task_filters).dependent(:destroy)
  should have_many(:sheets).dependent(:destroy)
  should have_many(:notes)
  should have_many(:preferences)

  def test_create
    u = User.new
    u.name = "a"
    u.username = "a"
    u.password = "a"
    u.email = "a@a.com"
    u.company = companies(:cit)
    u.save

    assert_not_nil u.uuid
    assert_not_nil u.autologin

    assert_equal u.uuid.length, 32
    assert_equal u.autologin.length, 32

    assert_equal u.widgets.size, 4
  end

  def test_validate_name
    u = User.new
    u.username = "a"
    u.password = "a"
    u.email = "a@a.com"
    u.company = companies(:cit)

    assert !u.save
    assert_equal 1, u.errors.size
    assert_equal "can't be blank", u.errors['name'].first

  end

  def test_validate_username
    u = User.new
    u.name = "a"
    u.password = "a"
    u.email = "a@a.com"
    u.company = companies(:cit)

    assert !u.save
    assert_equal 1, u.errors.size
    assert_equal "can't be blank", u.errors['username'].first

    u.username = 'test'
    assert !u.save
    assert_equal 1, u.errors.size
    assert_equal "has already been taken", u.errors['username'].first

  end

  def test_generate_uuid
    user = User.new
    user.generate_uuid

    assert_not_nil user.uuid
     assert_not_nil user.autologin

    assert user.uuid.length == 32
    assert user.autologin.length == 32
  end

  def test_avatar_url
    unless @user.avatar?
      assert_equal "http://www.gravatar.com/avatar.php?gravatar_id=7fe6da9c206af10497cdc35d63cf87a3&rating=PG&size=32", @user.avatar_url
      assert_equal "http://www.gravatar.com/avatar.php?gravatar_id=7fe6da9c206af10497cdc35d63cf87a3&rating=PG&size=25", @user.avatar_url(25)
    end
  end

  def test_display_name
    assert_equal "Erlend Simonsen", @user.name
  end

  def test_login
    assert_equal @user, @user.login(companies('cit'))
    assert_nil   @user.login
    assert_nil   @user.login('www')
    assert_nil   User.new.login('cit')
    assert_nil   users(:fudge).login('cit')
  end

  def test_can?
    project = projects(:test_project)
    normal = users(:tester)
    limited = users(:tester_limited)
    other = users(:fudge)

    %w(comment work close report create edit reassign milestone grant all).each do |perm|
       assert normal.can?(project, perm)
       assert !other.can?(project, perm)
      if %w(comment work).include? perm
        assert limited.can?(project, perm)
      else
        assert !limited.can?(project, perm)
      end
    end
  end

  def test_can_all?
    projects = [projects(:test_project), projects(:completed_project)]
    normal = users(:tester)
    limited = users(:tester_limited)
    other = users(:fudge)

    %w( comment work close report create edit reassign milestone grant all).each do |perm|
      assert normal.can_all?(projects, perm)
      assert !other.can_all?(projects, perm)
      assert !limited.can_all?(projects, perm)
    end
  end

  def test_admin?
    assert @user.admin?
    assert !users(:fudge).admin?
    assert !User.new.admin?
  end

  def test_moderator_of?
    # TODO
  end

  def test_avatar_url_without_email
    assert !@user.avatar?

    @user.email = nil
    assert_nil @user.avatar_url

    @user.email = "test@test.com"
    assert_not_nil @user.avatar_url
  end

  should "return true to can_view_task? when in project for that task" do
    task = @user.projects.first.tasks.first
    assert_not_nil task
    assert @user.can_view_task?(task)
  end
  should "return false to can_view_task? when not in project for that task" do
    task = @user.projects.first.tasks.first
    assert_not_nil task
    @user.projects.clear
    assert !@user.can_view_task?(task)
  end

  context "a user belonging to a company with a few filters" do
    setup do
      another_user = (@user.company.users - [ @user ]).rand
      assert_not_nil another_user

      @filter = TaskFilter.make(:user => @user)
      @filter1 = TaskFilter.make(:user => another_user, :shared => false)
      @filter2 = TaskFilter.make(:user => another_user, :shared => true)
      @filter3 = TaskFilter.make(:user => @user, :system => true)
    end

    should "return own filters from task_filters" do
      assert @user.private_task_filters.include?(@filter)
    end
    should "return others user's filters from visible task_filters" do
      @filter2.task_filter_users.make(:user_id => @user.id)
      assert @user.visible_task_filters.include?(@filter2)
    end
    should "not return others user's filters from visible task_filters" do
      assert !@user.visible_task_filters.include?(@filter2)
    end
    should "return others user's filters from shared task_filters" do
      assert @user.shared_task_filters.include?(@filter2)
    end
    should "not return others user's filters from shared task_filters" do
      assert !@user.shared_task_filters.include?(@filter1)
    end
    should "not return system filters" do
      assert !@user.visible_task_filters.include?(@filter3)
    end
  end

end




# == Schema Information
#
# Table name: users
#
#  id                         :integer(4)      not null, primary key
#  name                       :string(200)     default(""), not null
#  username                   :string(200)     default(""), not null
#  password                   :string(200)     default(""), not null
#  company_id                 :integer(4)      default(0), not null
#  created_at                 :datetime
#  updated_at                 :datetime
#  last_login_at              :datetime
#  admin                      :integer(4)      default(0)
#  time_zone                  :string(255)
#  option_tracktime           :integer(4)
#  option_tooltips            :integer(4)
#  seen_news_id               :integer(4)      default(0)
#  last_project_id            :integer(4)
#  last_seen_at               :datetime
#  last_ping_at               :datetime
#  last_milestone_id          :integer(4)
#  last_filter                :integer(4)
#  date_format                :string(255)     not null
#  time_format                :string(255)     not null
#  receive_notifications      :integer(4)      default(1)
#  uuid                       :string(255)     not null
#  seen_welcome               :integer(4)      default(0)
#  locale                     :string(255)     default("en_US")
#  duration_format            :integer(4)      default(0)
#  workday_duration           :integer(4)      default(480)
#  posts_count                :integer(4)      default(0)
#  newsletter                 :integer(4)      default(1)
#  option_avatars             :integer(4)      default(1)
#  autologin                  :string(255)     not null
#  remember_until             :datetime
#  option_floating_chat       :boolean(1)      default(TRUE)
#  days_per_week              :integer(4)      default(5)
#  enable_sounds              :boolean(1)      default(TRUE)
#  create_projects            :boolean(1)      default(TRUE)
#  show_type_icons            :boolean(1)      default(TRUE)
#  receive_own_notifications  :boolean(1)      default(TRUE)
#  use_resources              :boolean(1)
#  customer_id                :integer(4)
#  active                     :boolean(1)      default(TRUE)
#  read_clients               :boolean(1)      default(FALSE)
#  create_clients             :boolean(1)      default(FALSE)
#  edit_clients               :boolean(1)      default(FALSE)
#  can_approve_work_logs      :boolean(1)
#  auto_add_to_customer_tasks :boolean(1)
#  access_level_id            :integer(4)      default(1)
#  avatar_file_name           :string(255)
#  avatar_content_type        :string(255)
#  avatar_file_size           :integer(4)
#  avatar_updated_at          :datetime
#

