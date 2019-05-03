class MAPTheApp < Sinatra::Base

  Endpoint.get('/') do
    if Ctx.session[:username]
      # These tags get escaped...
      Templates.emit_with_layout(:hello, {
                                   :name => Ctx.session[:username],
                                   :agency => Ctx.client.get_current_agency,
                                   :location => Ctx.get.current_location
                                 },
                                 :layout, title: "Welcome", context: ['home'])
    else
      Templates.emit_with_layout(:login, {},
                                 :layout_blank, title: "Please log in")
    end
  end

  STATIC_JS_FILES = {
    'require.js' => 'ts/node_modules/requirejs/require.js',
    'materialize.min.js' => 'ts/node_modules/materialize-css/dist/js/materialize.min.js',
    'vue.js' => (MAPTheApp.production? ? 'ts/node_modules/vue/dist/vue.min.js' : 'ts/node_modules/vue/dist/vue.js'),
    'vue-resource.js' => 'ts/node_modules/vue-resource/dist/vue-resource.min.js',
  }

  Endpoint.get('/js/*')
    .param(:cb, String, "Cachebuster (ignored)", optional: true) do

    filename = request.path.split('/').last

    if JSBundle.has_bundle?(filename)
      send_file JSBundle.filename_for_bundle(filename)
    elsif (match = STATIC_JS_FILES.fetch(filename, nil))
      send_file match
    elsif File.exist?(file = File.join('js', filename))
      send_file file
    elsif File.exist?(file = File.join('buildjs', filename))
      send_file file
    else
      [404]
    end
  end

  Endpoint.get('/css/*')
    .param(:cb, String, "Cachebuster (ignored)", optional: true) do

    filename = request.path.split('/').last

    if filename == 'materialize.min.css'
      send_file 'ts/node_modules/materialize-css/dist/css/materialize.min.css'
    elsif File.exist?(file = File.join('css', filename))
      send_file file
    else
      [404]
    end
  end

  Endpoint.get('/webfonts/*') do
    filename = request.path.split('/').last
    if File.exist?(file = File.join('webfonts', filename))
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

      redirect '/'
    else
      Templates.emit_with_layout(:login, {username: params[:username], message: "Login failed"},
                                 :layout_blank, title: "Please log in")
    end
  end

  Endpoint.get('/users')
    .param(:page, Integer, "Page to return", optional: true) do
      Templates.emit_with_layout(:users, {paged_users: Ctx.client.users(params[:page] || 0)},
                                 :layout, title: "Users", context: ['users'])
  end

  Endpoint.get('/users/new') do
    Templates.emit_with_layout(:user_new, {user: UserUpdateRequest.new},
                               :layout, title: "New User", context: ['users'])
  end

  Endpoint.post('/users/create')
    .param(:user, UserUpdateRequest, "The user to create") do

    unless Ctx.permissions.is_admin?
      params[:user].is_admin = false
      if Ctx.permissions.is_senior_agency_admin?
        params[:user].agencies.select! do |agency|
          (Integer(agency['location_id']) == Ctx.get.current_location.id)
        end
      elsif Ctx.permissions.is_agency_admin?
        params[:user].agencies.select! do |agency|
          (Integer(agency['location_id']) == Ctx.get.current_location.id) && agency['role'] != 'SENIOR_AGENCY_ADMIN'
        end
      else
        # FIXME
        raise "Insufficient Privileges"
      end
    end

    params[:user].validate!

    Ctx.client.create_user(params[:user]) unless params[:user].has_errors?

    if params[:user].has_errors?
      Templates.emit_with_layout(:user_new, {user: params[:user]},
                                   :layout, title: "New User", context: ['users'])
    else
      redirect '/users'
    end
  end

  Endpoint.get('/users/edit')
    .param(:username, String, "Username") do
    unless Ctx.permissions.is_admin?
      # FIXME check permissions
    end

    Templates.emit_with_layout(:user_edit, {user: Ctx.client.user_for_edit(params[:username])},
                               :layout, title: "Edit User", context: ['users'])
  end

  Endpoint.post('/users/update/:id')
    .param(:id, Integer, "User id")
    .param(:user, UserUpdateRequest, "The user to update") do

    unless Ctx.permissions.is_admin?
      params[:user].is_admin = false
      if Ctx.permissions.is_senior_agency_admin?
        params[:user].agencies.select! do |agency|
          (Integer(agency['location_id']) == Ctx.get.current_location.id)
        end
      elsif Ctx.permissions.is_agency_admin?
        params[:user].agencies.select! do |agency|
          (Integer(agency['location_id']) == Ctx.get.current_location.id) && agency['role'] != 'SENIOR_AGENCY_ADMIN'
        end
      else
        # FIXME
        raise "Insufficient Privileges"
      end
    end

    params[:user].validate!

    Ctx.client.update_user(params[:user]) unless params[:user].has_errors?

    if params[:user].has_errors?
      Templates.emit_with_layout(:user_edit, {user: params[:user]},
                                 :layout, title: "Edit User", context: ['users'])
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

  Endpoint.get('/locations')
    .param(:page, Integer, "Page to return", optional: true) do

    if Ctx.permissions.allow_manage_locations?
      Templates.emit_with_layout(:locations, {paged_results: Ctx.client.locations(params[:page] || 0)},
                                 :layout, title: "Locations", context: ['locations'])
    else
      [404]
    end
  end

  Endpoint.get('/locations/new') do
    if Ctx.permissions.allow_manage_locations?
      Templates.emit_with_layout(:location_new, {location: AgencyLocationUpdateRequest.new},
                                 :layout, title: "New Location", context: ['locations'])
    else
      [404]
    end
  end

  Endpoint.post('/locations/create')
    .param(:location, AgencyLocationUpdateRequest, "The agency location to create") do

    return [404] unless Ctx.permissions.allow_manage_locations?

    unless Ctx.permissions.is_admin?
        params[:location].agency_ref = Ctx.get.current_location.agency.id
    end

    Ctx.client.create_location(params[:location])

    if params[:location].has_errors?
      Templates.emit_with_layout(:location_new, {location: params[:location]},
                                 :layout, title: "New Location", context: ['locations'])
    else
      redirect '/locations'
    end
  end

  Endpoint.get('/linker_data_for_agency')
    .param(:agency_ref, String, "Agency Ref") do
    if Ctx.permissions.is_admin?
      [
        200,
        {'Content-type' => 'text/json'},
        {
          'location_options' => Ctx.client.locations_for_agency(params[:agency_ref]).map(&:to_search_result),
          # FIXME some shared lib?
          'permission_options' => Ctx.client.permission_options
        }.to_json
      ]
    else
      [404]
    end
  end

  Endpoint.post('/set-location')
    .param(:agency_id, Integer, "Agency Id")
    .param(:location_id, Integer, "Location Id") do

    Ctx.client.set_location(params[:agency_id], params[:location_id])

    [
      200,
      {'Content-type' => 'text/json'},
      {
        'status' => 'ok'
      }.to_json
    ]
  end

  Endpoint.get('/transfer_proposals')
    .param(:page, Integer, "Page to return", optional: true) do

    Templates.emit_with_layout(:transfer_proposals, {paged_results: Ctx.client.transfers(params[:page] || 0)},
                               :layout, title: "Transfer Proposals", context: ['transfers', 'transfer_proposals'])
  end

  Endpoint.get('/transfer_proposals/new') do
    Templates.emit_with_layout(:transfer_proposal_new, {transfer: TransferProposal.new, is_readonly: false},
                               :layout, title: "New Transfer Proposal", context: ['transfers', 'transfer_proposals'])
  end

  Endpoint.post('/transfer_proposals/create')
    .param(:transfer, TransferProposal, "The transfer to create") do

    errors = Ctx.client.create_transfer_proposal(params[:transfer])

    if errors.empty?
      redirect '/transfer_proposals'
    else
      Templates.emit_with_layout(:transfer_proposal_new, {transfer: params[:transfer], errors: errors},
                                 :layout, title: "New Transfer Proposal", context: ['transfers', 'transfer_proposals'])
    end
  end

  Endpoint.post('/file-upload')
    .param(:file, [UploadFile], "Files to upload") do
    files = []
    Ctx.client.store_files(params[:file]).zip(params[:file]).map do |file_key, file|
      files << {
        'key' => file_key,
        'filename' => file.filename,
      }
    end

    [
      200,
      {'Content-type' => 'text/json'},
      files.to_json
    ]
  end

  Endpoint.get('/transfer_proposals/:id')
    .param(:id, Integer, "ID of transfer proposal") do
    transfer = Ctx.client.get_transfer_proposal(params[:id])
    if false
      # FIXME check permissions and agency/location etc
      # return [404]
    end

    Templates.emit_with_layout(:transfer_proposal_view, {transfer: transfer, is_readonly: (transfer.fetch('status') != 'ACTIVE')},
                               :layout, title: "Transfer Proposal", context: ['transfers', 'transfer_proposals'])
  end

  Endpoint.post('/transfer_proposals/update')
    .param(:transfer, TransferProposal, "The transfer to create") do

    # FIXME check permissions

    errors = Ctx.client.update_transfer_proposal(params[:transfer])

    if errors.empty?
      redirect '/transfer_proposals'
    else
      Templates.emit_with_layout(:transfer_proposal_view,
                                 {
                                   transfer: params[:transfer],
                                   errors: errors,
                                   is_readonly: false,
                                 },
                                 :layout, title: "Transfer Proposal", context: ['transfers', 'transfer_proposals'])
    end
  end

  Endpoint.post('/transfer_proposals/:id/cancel')
    .param(:id, Integer, "The ID of the transfer to cancel") do

    # FIXME check permissions

    Ctx.client.cancel_transfer_proposal(params[:id])

    redirect '/transfer_proposals'
  end

  Endpoint.get('/file-download')
    .param(:key, String, "File key")
    .param(:filename, String, "Filename") do
    [
      200,
      {
        'Content-Type' => 'application/octet-stream',
        'Content-Disposition' => "attachment; filename=#{params[:filename]}"
      },
      Ctx.client.stream_file(params[:key])
    ]
  end

  Endpoint.get('/transfers')
    .param(:page, Integer, "Page to return", optional: true) do

    Templates.emit_with_layout(:transfers, {paged_results: Ctx.client.transfers(params[:page] || 0)},
                               :layout, title: "Transfers", context: ['transfers', 'active_transfers'])
  end

  Endpoint.get('/get_messages')
    .param(:record_type, String, "Record Type")
    .param(:id, Integer, "Record ID") do

    # FIXME permissions check!
    [
      200,
      {'Content-type' => 'text/json'},
      {
        'messages' => Ctx.client.get_messages(params[:record_type], params[:id]),
      }.to_json
    ]
  end

  Endpoint.post('/post_message')
    .param(:message, String, "Message")
    .param(:record_type, String, "Record Type")
    .param(:id, Integer, "Record ID") do

    # FIXME check permissions, error handling

    Ctx.client.post_message(params[:record_type], params[:id], params[:message])

    [
      200,
      {'Content-type' => 'text/json'},
      {'status' => 'success'}.to_json
    ]
  end
end
