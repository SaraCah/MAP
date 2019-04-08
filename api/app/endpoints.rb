class MAPTheAPI < Sinatra::Base

  Endpoint.get('/') do
    json_response({
                    hello: "GREETINGS #{Ctx.username}"
                  })
  end

  Endpoint.post('/logout') do
    Sessions.delete_session(Ctx.get.session.id)
    json_response({ bye: "Bye!" })
  end

  Endpoint.post('/authenticate')
    .param(:username, String, "Username to authenticate")
    .param(:password, String, "Password") do
    if DBAuth.authenticate(params[:username], params[:password])
      json_response(authenticated: true,
                    session: Sessions.create_session(params[:username]))
    else
      json_response(authenticated: false)
    end
  end

end
