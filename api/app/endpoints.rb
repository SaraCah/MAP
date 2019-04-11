class MAPTheAPI < Sinatra::Base

  Endpoint.get('/') do
    if Ctx.user_logged_in?
      json_response(hello: "GREETINGS #{Ctx.username}")
    else
      json_response(hello: "GREETINGS")
    end
  end

  Endpoint.post('/logout') do
    Sessions.delete_session(Ctx.get.session.id)
    json_response({ bye: "Bye!" })
  end

  Endpoint.post('/authenticate', needs_session: false)
    .param(:username, String, "Username to authenticate")
    .param(:password, String, "Password") do
    if DBAuth.authenticate(params[:username], params[:password])
      json_response(authenticated: true,
                    permissions: Users.permissions_for(params[:username]),
                    session: Sessions.create_session(params[:username]))
    else
      json_response(authenticated: false)
    end
  end

  Endpoint.get('/users')
    .param(:page, Integer, "Page to return") do
    if Ctx.user_logged_in?
      if Ctx.get.permissions.is_admin
        json_response(Users.page('ANY', params[:page], 10))
      else
        admin_agencies = Ctx.get.permissions.agencies.select{|_, role| role == 'ADMIN'}.keys
        json_response(Users.page(admin_agencies, params[:page], 10))
      end
    else
      json_response([])
    end
  end

  Endpoint.post('/users/create')
    .param(:user, UserRequest, "User") do
    Users.create_from_dto(params[:user])

    if params[:user].valid?
      json_response(status: 'created')
    else
      json_response(errors: params[:user].errors)
    end
  end

  Endpoint.get('/search/agencies')
    .param(:q, String, "Search string") do
    permissions = Users.permissions_for_user(Ctx.username)
    json_response(Search.agency_typeahead(params[:q], permissions))
  end

  Endpoint.get('/my-agencies') do
    if Ctx.user_logged_in?
      json_response(Users.agencies_for_user(Ctx.username))
    else
      json_response([])
    end
  end

  Endpoint.get('/my-permissions') do
    if Ctx.user_logged_in?
      json_response(Users.permissions_for_user(Ctx.username))
    else
      json_response([])
    end
  end

end
