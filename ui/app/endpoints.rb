class MAPTheApp < Sinatra::Base

  Endpoint.get('/') do
    if Ctx.session[:username]
      # These tags get escaped...
      Templates.emit_with_layout(:hello, {:name => "<b>#{Ctx.session[:username]}</b>"},
                                 :layout, title: "Welcome")
    else
      Templates.emit_with_layout(:login, {},
                                 :layout, title: "Please log in")
    end
  end

  Endpoint.get('/js/*') do
    filename = request.path.split('/').last

    if filename == 'vue.js'
      send_file File.join('ts/node_modules/vue/dist/vue.js')
    elsif filename == 'vue-resource.js'
      send_file File.join('ts/node_modules/vue-resource/dist/vue-resource.min.js')
    else
      if File.exist?(file = File.join('js', filename))
        send_file file
      elsif File.exist?(file = File.join('buildjs', filename))
        send_file file
      else
        [404]
      end
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
    authentication = Ctx.client.authenticate(params[:username], params[:password])

    if authentication.successful?
      session[:api_session_id] = authentication.session_id or raise "WOOT"
      session[:username] = params[:username]
      session[:permissions] = authentication.permissions

      redirect '/'
    else
      Templates.emit_with_layout(:login, {username: params[:username]},
                                 :layout, title: "Please log in", message: "Login failed")
    end
  end

  Endpoint.get('/users')
    .param(:page, Integer, "Page to return", optional: true) do
      Templates.emit_with_layout(:users, {users: Ctx.client.users(params[:page] || 0)},
                                 :layout, title: "Users")
  end

  Endpoint.get('/users/new') do
    Templates.emit_with_layout(:user_new, {user: UserForm.new},
                               :layout, title: "New User")
  end

  Endpoint.post('/users/create')
    .param(:user, UserForm, "The user to create") do

    Ctx.client.create_user(params[:user])

    if params[:user].has_errors?
      Templates.emit_with_layout(:user_new, {user: params[:user]},
                                   :layout, title: "New User")
    else
      redirect '/users'
    end
  end

  Endpoint.get('/logout') do
    session[:api_session_id] = nil
    session[:username] = nil

    # [200, "Woot"]
    redirect '/'
  end

  Endpoint.get('/search/agencies')
    .param(:q, String, "Search string") do
    [
      200,
      {'Content-type' => 'text/json'},
      Ctx.client.agency_typeahead(params[:q]).to_json
    ]
  end

end
