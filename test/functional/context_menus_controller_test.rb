# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path('../../test_helper', __FILE__)

class ContextMenusControllerTest < ActionController::TestCase
  fixtures :projects,
           :trackers,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :workflows,
           :journals, :journal_details,
           :versions,
           :issues, :issue_statuses, :issue_categories,
           :users,
           :enumerations,
           :time_entries

  def test_context_menu_one_issue
    @request.session[:user_id] = 2
    get :issues, :ids => [1]
    assert_response :success
    assert_template 'context_menus/issues'

    assert_select 'a.icon-edit[href=?]', '/issues/1/edit', :text => 'Edit'
    assert_select 'a.icon-copy[href=?]', '/projects/ecookbook/issues/1/copy', :text => 'Copy'
    assert_select 'a.icon-del[href=?]', '/issues?ids%5B%5D=1', :text => 'Delete'

    # Statuses
    assert_select 'a[href=?]', '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bstatus_id%5D=5', :text => 'Closed'
    assert_select 'a[href=?]', '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bpriority_id%5D=8', :text => 'Immediate'
    # No inactive priorities
    assert_select 'a', :text => /Inactive Priority/, :count => 0
    # Versions
    assert_select 'a[href=?]', '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bfixed_version_id%5D=3', :text => '2.0'
    assert_select 'a[href=?]', '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bfixed_version_id%5D=4', :text => 'eCookbook Subproject 1 - 2.0'
    # Assignees
    assert_select 'a[href=?]', '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bassigned_to_id%5D=3', :text => 'Dave Lopper'
  end

  def test_context_menu_one_issue_by_anonymous
    with_settings :default_language => 'en' do
      get :issues, :ids => [1]
      assert_response :success
      assert_template 'context_menus/issues'
      assert_select 'a.icon-del.disabled[href="#"]', :text => 'Delete'
    end
  end

  def test_context_menu_multiple_issues_of_same_project
    @request.session[:user_id] = 2
    get :issues, :ids => [1, 2]
    assert_response :success
    assert_template 'context_menus/issues'
    assert_not_nil assigns(:issues)
    assert_equal [1, 2], assigns(:issues).map(&:id).sort

    ids = assigns(:issues).map(&:id).sort.map {|i| "ids%5B%5D=#{i}"}.join('&amp;')

    assert_select 'a.icon-edit[href=?]', "/issues/bulk_edit?#{ids}", :text => 'Edit'
    assert_select 'a.icon-copy[href=?]', "/issues/bulk_edit?copy=1&amp;#{ids}", :text => 'Copy'
    assert_select 'a.icon-del[href=?]', "/issues?#{ids}", :text => 'Delete'

    assert_select 'a[href=?]', "/issues/bulk_update?#{ids}&amp;issue%5Bstatus_id%5D=5", :text => 'Closed'
    assert_select 'a[href=?]', "/issues/bulk_update?#{ids}&amp;issue%5Bpriority_id%5D=8", :text => 'Immediate'
    assert_select 'a[href=?]', "/issues/bulk_update?#{ids}&amp;issue%5Bassigned_to_id%5D=3", :text => 'Dave Lopper'
  end

  def test_context_menu_multiple_issues_of_different_projects
    @request.session[:user_id] = 2
    get :issues, :ids => [1, 2, 6]
    assert_response :success
    assert_template 'context_menus/issues'
    assert_not_nil assigns(:issues)
    assert_equal [1, 2, 6], assigns(:issues).map(&:id).sort

    ids = assigns(:issues).map(&:id).sort.map {|i| "ids%5B%5D=#{i}"}.join('&amp;')

    assert_select 'a.icon-edit[href=?]', "/issues/bulk_edit?#{ids}", :text => 'Edit'
    assert_select 'a.icon-del[href=?]', "/issues?#{ids}", :text => 'Delete'

    assert_select 'a[href=?]', "/issues/bulk_update?#{ids}&amp;issue%5Bstatus_id%5D=5", :text => 'Closed'
    assert_select 'a[href=?]', "/issues/bulk_update?#{ids}&amp;issue%5Bpriority_id%5D=8", :text => 'Immediate'
    assert_select 'a[href=?]', "/issues/bulk_update?#{ids}&amp;issue%5Bassigned_to_id%5D=2", :text => 'John Smith'
  end

  def test_context_menu_should_include_list_custom_fields
    field = IssueCustomField.create!(:name => 'List', :field_format => 'list',
      :possible_values => ['Foo', 'Bar'], :is_for_all => true, :tracker_ids => [1, 2, 3])
    @request.session[:user_id] = 2
    get :issues, :ids => [1]

    assert_select "li.cf_#{field.id}" do
      assert_select 'a[href=#]', :text => 'List'
      assert_select 'ul' do
        assert_select 'a', 3
        assert_select 'a[href=?]', "/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bcustom_field_values%5D%5B#{field.id}%5D=Foo", :text => 'Foo'
        assert_select 'a[href=?]', "/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bcustom_field_values%5D%5B#{field.id}%5D=__none__", :text => 'none'
      end
    end
  end

  def test_context_menu_should_not_include_null_value_for_required_custom_fields
    field = IssueCustomField.create!(:name => 'List', :is_required => true, :field_format => 'list',
      :possible_values => ['Foo', 'Bar'], :is_for_all => true, :tracker_ids => [1, 2, 3])
    @request.session[:user_id] = 2
    get :issues, :ids => [1, 2]

    assert_select "li.cf_#{field.id}" do
      assert_select 'a[href=#]', :text => 'List'
      assert_select 'ul' do
        assert_select 'a', 2
        assert_select 'a', :text => 'none', :count => 0
      end
    end
  end

  def test_context_menu_on_single_issue_should_select_current_custom_field_value
    field = IssueCustomField.create!(:name => 'List', :field_format => 'list',
      :possible_values => ['Foo', 'Bar'], :is_for_all => true, :tracker_ids => [1, 2, 3])
    issue = Issue.find(1)
    issue.custom_field_values = {field.id => 'Bar'}
    issue.save!
    @request.session[:user_id] = 2
    get :issues, :ids => [1]

    assert_select "li.cf_#{field.id}" do
      assert_select 'a[href=#]', :text => 'List'
      assert_select 'ul' do
        assert_select 'a', 3
        assert_select 'a.icon-checked', :text => 'Bar'
      end
    end
  end

  def test_context_menu_should_include_bool_custom_fields
    field = IssueCustomField.create!(:name => 'Bool', :field_format => 'bool',
      :is_for_all => true, :tracker_ids => [1, 2, 3])
    @request.session[:user_id] = 2
    get :issues, :ids => [1]

    assert_select "li.cf_#{field.id}" do
      assert_select 'a[href=#]', :text => 'Bool'
      assert_select 'ul' do
        assert_select 'a', 3
        assert_select 'a[href=?]', "/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bcustom_field_values%5D%5B#{field.id}%5D=0", :text => 'No'
        assert_select 'a[href=?]', "/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bcustom_field_values%5D%5B#{field.id}%5D=1", :text => 'Yes'
        assert_select 'a[href=?]', "/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bcustom_field_values%5D%5B#{field.id}%5D=__none__", :text => 'none'
      end
    end
  end

  def test_context_menu_should_include_user_custom_fields
    field = IssueCustomField.create!(:name => 'User', :field_format => 'user',
      :is_for_all => true, :tracker_ids => [1, 2, 3])
    @request.session[:user_id] = 2
    get :issues, :ids => [1]

    assert_select "li.cf_#{field.id}" do
      assert_select 'a[href=#]', :text => 'User'
      assert_select 'ul' do
        assert_select 'a', Project.find(1).members.count + 1
        assert_select 'a[href=?]', "/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bcustom_field_values%5D%5B#{field.id}%5D=2", :text => 'John Smith'
        assert_select 'a[href=?]', "/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bcustom_field_values%5D%5B#{field.id}%5D=__none__", :text => 'none'
      end
    end
  end

  def test_context_menu_should_include_version_custom_fields
    field = IssueCustomField.create!(:name => 'Version', :field_format => 'version', :is_for_all => true, :tracker_ids => [1, 2, 3])
    @request.session[:user_id] = 2
    get :issues, :ids => [1]

    assert_select "li.cf_#{field.id}" do
      assert_select 'a[href=#]', :text => 'Version'
      assert_select 'ul' do
        assert_select 'a', Project.find(1).shared_versions.count + 1
        assert_select 'a[href=?]', "/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bcustom_field_values%5D%5B#{field.id}%5D=3", :text => '2.0'
        assert_select 'a[href=?]', "/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bcustom_field_values%5D%5B#{field.id}%5D=__none__", :text => 'none'
      end
    end
  end

  def test_context_menu_should_show_enabled_custom_fields_for_the_role_only
    enabled_cf = IssueCustomField.generate!(:field_format => 'bool', :is_for_all => true, :tracker_ids => [1], :visible => false, :role_ids => [1,2])
    disabled_cf = IssueCustomField.generate!(:field_format => 'bool', :is_for_all => true, :tracker_ids => [1], :visible => false, :role_ids => [2])
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1)

    @request.session[:user_id] = 2
    get :issues, :ids => [issue.id]

    assert_select "li.cf_#{enabled_cf.id}"
    assert_select "li.cf_#{disabled_cf.id}", 0
  end

  def test_context_menu_by_assignable_user_should_include_assigned_to_me_link
    @request.session[:user_id] = 2
    get :issues, :ids => [1]
    assert_response :success
    assert_template 'context_menus/issues'

    assert_select 'a[href=?]', '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bassigned_to_id%5D=2', :text => / me /
  end

  def test_context_menu_should_propose_shared_versions_for_issues_from_different_projects
    @request.session[:user_id] = 2
    version = Version.create!(:name => 'Shared', :sharing => 'system', :project_id => 1)

    get :issues, :ids => [1, 4]
    assert_response :success
    assert_template 'context_menus/issues'

    assert_include version, assigns(:versions)
    assert_select 'a', :text => 'eCookbook - Shared'
  end

  def test_context_menu_with_issue_that_is_not_visible_should_fail
    get :issues, :ids => [1, 4] # issue 4 is not visible
    assert_response 302
  end

  def test_should_respond_with_404_without_ids
    get :issues
    assert_response 404
  end

  def test_time_entries_context_menu
    @request.session[:user_id] = 2
    get :time_entries, :ids => [1, 2]
    assert_response :success
    assert_template 'context_menus/time_entries'

    assert_select 'a:not(.disabled)', :text => 'Edit'
  end

  def test_context_menu_for_one_time_entry
    @request.session[:user_id] = 2
    get :time_entries, :ids => [1]
    assert_response :success
    assert_template 'context_menus/time_entries'

    assert_select 'a:not(.disabled)', :text => 'Edit'
  end

  def test_time_entries_context_menu_should_include_custom_fields
    field = TimeEntryCustomField.generate!(:name => "Field", :field_format => "list", :possible_values => ["foo", "bar"])

    @request.session[:user_id] = 2
    get :time_entries, :ids => [1, 2]
    assert_response :success
    assert_select "li.cf_#{field.id}" do
      assert_select 'a[href=#]', :text => "Field"
      assert_select 'ul' do
        assert_select 'a', 3
        assert_select 'a[href=?]', "/time_entries/bulk_update?ids%5B%5D=1&amp;ids%5B%5D=2&amp;time_entry%5Bcustom_field_values%5D%5B#{field.id}%5D=foo", :text => 'foo'
        assert_select 'a[href=?]', "/time_entries/bulk_update?ids%5B%5D=1&amp;ids%5B%5D=2&amp;time_entry%5Bcustom_field_values%5D%5B#{field.id}%5D=bar", :text => 'bar'
        assert_select 'a[href=?]', "/time_entries/bulk_update?ids%5B%5D=1&amp;ids%5B%5D=2&amp;time_entry%5Bcustom_field_values%5D%5B#{field.id}%5D=__none__", :text => 'none'
      end
    end
  end

  def test_time_entries_context_menu_without_edit_permission
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :edit_time_entries
    
    get :time_entries, :ids => [1, 2]
    assert_response :success
    assert_template 'context_menus/time_entries'
    assert_select 'a.disabled', :text => 'Edit'
  end
end
