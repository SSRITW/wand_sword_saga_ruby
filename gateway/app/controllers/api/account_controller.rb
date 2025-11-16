class Api::AccountController < ApplicationController
  # POST /api/account/login
  def login
    # 获取参数 / パラメータを取得
    account_name = params[:account_name]
    platform_id = params[:platform_id]&.to_i  # 转换为整数 / 整数に変換
    platform_type = params[:platform_type]&.to_i  # 转换为整数 / 整数に変換

    # 验证参数 / パラメータを検証
    if account_name.blank? || platform_id.nil? || platform_type.nil?
      return render json: { error: 'Missing required parameters' }, status: :bad_request
    end

    # 调用服务层处理登录逻辑 / サービス層を呼び出してログイン処理を実行
    result = AccountService.login_of_register(account_name: account_name, platform_id: platform_id, platform_type: platform_type)

    # 根据结果返回响应 / 結果に応じてレスポンスを返す
    if result[:code] == 1
      render json: result, status: :ok
    else
      render json: result, status: :unprocessable_entity
    end
  end
end