class MAPTheApp < Sinatra::Base

  Endpoint.get('/') do
    if Ctx.session[:username]
      # These tags get escaped...
      Templates.emit(:hello, :name => "<b>#{Ctx.session[:username]}</b>")
    else
      Templates.emit_with_layout(:login, {},
                                 :layout, title: "Please log in")
    end
  end

  Endpoint.get('/js/*') do
    filename = request.path.split('/').last
    if File.exist?(file = File.join('js', filename))
      send_file file
    elsif File.exist?(file = File.join('buildjs', filename))
      send_file file
    else
      [404]
    end
  end

  Endpoint.get('/css/*') do
    filename = request.path.split('/').last
    if File.exist?(file = File.join('css', filename))
      send_file file
    else
      [404]
    end
  end

  Endpoint.post('/authenticate')
   .param(:username, String, "Username to authenticate")
   .param(:password, String, "Password") do 
     begin
       session[:session_id] = Ctx.client.authenticate(params[:username], params[:password])
       session[:username] = params[:username]

       redirect '/'
     rescue MAPAPIClient::AuthenticationFailed
       Templates.emit_with_layout(:login, {username: params[:username]},
                                  :layout, title: "Please log in", message: "Login failed")
     end
  end

end
