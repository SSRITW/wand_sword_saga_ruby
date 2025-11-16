require "test_helper"

class Api::AccountControllerTest < ActionDispatch::IntegrationTest
  test "should get login" do
    get api_account_login_url
    assert_response :success
  end
end
