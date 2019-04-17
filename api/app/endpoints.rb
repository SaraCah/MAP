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
                    session: Sessions.create_session(params[:username]))
    else
      json_response(authenticated: false)
    end
  end

  Endpoint.get('/users')
    .param(:page, Integer, "Page to return") do
    if Ctx.user_logged_in?
      json_response(Users.page(params[:page], 10))
    else
      json_response([])
    end
  end

  Endpoint.post('/users/create')
    .param(:user, UserUpdateRequest, "User") do
    Users.create_from_dto(params[:user])

    if params[:user].has_errors?
      json_response(errors: params[:user].errors)
    else
      json_response(status: 'created')
    end
  end

  Endpoint.get('/search/agencies')
    .param(:q, String, "Search string") do
    permissions = Users.permissions_for_user(Ctx.username)
    json_response(Search.agency_typeahead(params[:q], permissions))
  end

  Endpoint.get('/my-agencies') do
    if Ctx.user_logged_in?
      json_response(Agencies.agencies_for_user)
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

  Endpoint.get('/locations')
    .param(:page, Integer, "Page to return") do
    if Ctx.user_logged_in?
      json_response(Locations.page(params[:page], 10))
    else
      json_response([])
    end
  end

  Endpoint.get('/locations_for_agency')
    .param(:agency_ref, String, "Agency Ref") do
    if Ctx.user_logged_in?
      (_, aspace_agency_id) =  params[:agency_ref].split(':')

      json_response(Locations.locations_for_agency(aspace_agency_id))
    else
      json_response([])
    end
  end

  Endpoint.post('/locations/create')
    .param(:location, AgencyLocationUpdateRequest, "Location") do
    Locations.create_location_from_dto(params[:location])

    if params[:location].has_errors?
      json_response(errors: params[:location].errors)
    else
      json_response(status: 'created')
    end
  end

end
