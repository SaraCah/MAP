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

  if MAPTheApp.development?
    # Serve out TS for debugging
    Endpoint.get('/ts/*')
      .param(:cb, String, "Cachebuster (ignored)", optional: true) do

      filename = request.path.split('/').last

      if File.exist?(file = File.join('ts', filename))
        send_file file
      else
        [404]
      end
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
    Templates.emit_with_layout(:user_new, {user: UserDTO.new},
                               :layout, title: "New User", context: ['users'])
  end

  Endpoint.post('/users/create')
    .param(:user, UserDTO, "The user to create") do

    unless Ctx.permissions.is_admin?
      params[:user]['is_admin'] = false
      if Ctx.permissions.is_senior_agency_admin?
        params[:user].fetch('agency_roles', []).select! do |agency_role|
          Integer(agency_role.fetch('agency_location_id')) == Ctx.get.current_location.id
        end
      elsif Ctx.permissions.is_agency_admin?
        params[:user].fetch('agency_roles', []).select! do |agency_role|
          Integer(agency_role.fetch('agency_location_id')) == Ctx.get.current_location.id && agency_role.fetch('role', '') != 'SENIOR_AGENCY_ADMIN'
        end
      else
        # FIXME
        raise "Insufficient Privileges"
      end
    end

    errors = Ctx.client.create_user(params[:user])

    if errors.empty?
      redirect '/users'
    else
      Templates.emit_with_layout(:user_new, {user: params[:user], errors: errors},
                                 :layout, title: "New User", context: ['users'])
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
    .param(:user, UserDTO, "The user to update") do

    unless Ctx.permissions.is_admin?
      params[:user]['is_admin'] = false
      if Ctx.permissions.is_senior_agency_admin?
        params[:user].fetch('agency_roles', []).select! do |agency_role|
          Integer(agency_role.fetch('agency_location_id')) == Ctx.get.current_location.id
        end
      elsif Ctx.permissions.is_agency_admin?
        params[:user].fetch('agency_roles', []).select! do |agency_role|
          Integer(agency_role.fetch('agency_location_id')) == Ctx.get.current_location.id && agency_role.fetch('role', '') != 'SENIOR_AGENCY_ADMIN'
        end
      else
        # FIXME
        raise "Insufficient Privileges"
      end
    end
    
    errors = Ctx.client.update_user(params[:user])

    if errors.empty?
      redirect '/users'
    else
      Templates.emit_with_layout(:user_edit, {user: params[:user], errors: errors},
                                 :layout, title: "Edit User", context: ['users'])
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
      Templates.emit_with_layout(:location_new, {location: AgencyLocationDTO.new},
                                 :layout, title: "New Location", context: ['locations'])
    else
      [404]
    end
  end

  Endpoint.post('/locations/create')
    .param(:location, AgencyLocationDTO, "The agency location to create") do

    return [404] unless Ctx.permissions.allow_manage_locations?

    unless Ctx.permissions.is_admin?
        params[:location]['agency_ref'] = Ctx.get.current_location.agency.id
    end

    errors = Ctx.client.create_location(params[:location])

    if errors.empty?
      redirect '/locations'
    else
      Templates.emit_with_layout(:location_new, {location: params[:location], errors: errors},
                                 :layout, title: "New Location", context: ['locations'])
    end
  end

  Endpoint.get('/locations/:id')
    .param(:id, Integer, "ID of agency location") do
    location = Ctx.client.location_for_edit(params[:id])
    if false
      # FIXME check permissions and agency/location etc
      # return [404]
    end

    Templates.emit_with_layout(:location_edit, {location: location},
                               :layout, title: "Location", context: ['locations'])
  end

  Endpoint.post('/locations/update')
    .param(:location, AgencyLocationDTO, "The location to update") do

    return [404] unless Ctx.permissions.allow_manage_locations?

    unless Ctx.permissions.is_admin?
      params[:location]['agency_ref'] = Ctx.get.current_location.agency.id
    end

    errors = Ctx.client.update_location(params[:location])

    if errors.empty?
      redirect '/locations'
    else
      Templates.emit_with_layout(:location_edit, {location: params[:location], errors: errors},
                                 :layout, title: "Location", context: ['locations'])
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

  Endpoint.get('/transfer-proposals')
    .param(:page, Integer, "Page to return", optional: true) do

    Templates.emit_with_layout(:transfer_proposals, {paged_results: Ctx.client.transfer_proposals(params[:page] || 0)},
                               :layout, title: "Transfer Proposals", context: ['transfers', 'transfer_proposals'])
  end

  Endpoint.get('/transfer-proposals/new') do
    Templates.emit_with_layout(:transfer_proposal_new, {transfer: TransferProposal.new, is_readonly: false},
                               :layout, title: "New Transfer Proposal", context: ['transfers', 'transfer_proposals'])
  end

  Endpoint.post('/transfer-proposals/create')
    .param(:transfer, TransferProposal, "The transfer to create") do

    errors = Ctx.client.create_transfer_proposal(params[:transfer])

    if errors.empty?
      redirect '/transfer-proposals'
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
        'mime_type' => file.mime_type,
        'filename' => file.filename,
      }
    end

    [
      200,
      {'Content-type' => 'text/json'},
      files.to_json
    ]
  end

  Endpoint.get('/transfer-proposals/:id')
    .param(:id, Integer, "ID of transfer proposal") do
    transfer = Ctx.client.get_transfer_proposal(params[:id])
    if false
      # FIXME check permissions and agency/location etc
      # return [404]
    end

    Templates.emit_with_layout(:transfer_proposal_view, {transfer: transfer, is_readonly: (transfer.fetch('status') != 'ACTIVE')},
                               :layout, title: "Transfer Proposal", context: ['transfers', 'transfer_proposals'])
  end

  Endpoint.post('/transfer-proposals/update')
    .param(:transfer, TransferProposal, "The transfer to update") do

    # FIXME check permissions

    errors = Ctx.client.update_transfer_proposal(params[:transfer])

    if errors.empty?
      redirect '/transfer-proposals'
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

  Endpoint.post('/transfer-proposals/:id/cancel')
    .param(:id, Integer, "The ID of the transfer to cancel") do

    # FIXME check permissions

    Ctx.client.cancel_transfer_proposal(params[:id])

    redirect '/transfer-proposals'
  end

  Endpoint.get('/file-download')
    .param(:key, String, "File key")
    .param(:mime_type, String, "MIME type of file")
    .param(:filename, String, "Filename") do
    [
      200,
      {
        'Content-Type' => params[:mime_type],
        'Content-Disposition' => "attachment; filename=#{params[:filename]}"
      },
      Ctx.client.stream_file(params[:key])
    ]
  end

  Endpoint.get('/transfers')
    .param(:page, Integer, "Page to return", optional: true) do

    Templates.emit_with_layout(:transfers, {paged_results: Ctx.client.transfers(params[:page] || 0)},
                               :layout, title: "Transfers", context: ['transfers', 'initiated_transfers'])
  end

  Endpoint.get('/get-messages')
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

  Endpoint.post('/post-message')
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

  Endpoint.get('/transfers/:id')
    .param(:id, Integer, "ID of transfer") do
    transfer = Ctx.client.get_transfer(params[:id])
    if false
      # FIXME check permissions and agency/location etc
      # return [404]
    end

    Templates.emit_with_layout(:transfer_view, {transfer: transfer, is_readonly: (transfer.fetch('status') == 'COMPLETE')},
                               :layout, title: "Transfer", context: ['transfers', 'initiated_transfers'])
  end

  Endpoint.post('/transfers/update')
    .param(:transfer, Transfer, "The transfer to update") do

    # FIXME check permissions

    errors = Ctx.client.update_transfer(params[:transfer])

    if errors.empty?
      redirect '/transfers'
    else
      Templates.emit_with_layout(:transfer_view,
                                 {
                                   transfer: params[:transfer],
                                   errors: errors,
                                   is_readonly: false,
                                 },
                                 :layout, title: "Transfer", context: ['transfers', 'initiated_transfers'])
    end
  end

  Endpoint.get('/csv-validate')
    .param(:key, String, "The file key to validate") do
    result = Ctx.client.csv_validate(params[:key])

    [
      200,
      {'Content-type' => 'text/json'},
      result.to_json
    ]
  end

  Endpoint.get('/file-issue-requests')
    .param(:page, Integer, "Page to return", optional: true) do

    Templates.emit_with_layout(:file_issue_requests, {paged_results: Ctx.client.file_issue_requests(params[:page] || 0)},
                               :layout, title: "File Issue Requests", context: ['file_issues', 'file_issue_requests'])
  end

  Endpoint.get('/file-issue-requests/new') do
    Templates.emit_with_layout(:file_issue_request_new, {request: FileIssueRequest.new, is_readonly: false},
                               :layout, title: "New Request", context: ['file_issues', 'file_issue_requests'])
  end

  Endpoint.post('/file-issue-requests/create')
    .param(:file_issue_request, FileIssueRequest, "The file issue request to create") do

    errors = Ctx.client.create_file_issue_request(params[:file_issue_request])

    if errors.empty?
      redirect '/file-issue-requests'
    else
      Templates.emit_with_layout(:file_issue_request_new, {request: params[:file_issue_request], errors: errors},
                                 :layout, title: "New Request", context: ['file_issues', 'file_issue_requests'])
    end
  end

  Endpoint.get('/file-issue-requests/:id')
    .param(:id, Integer, "ID of file issue request") do
    file_issue_request = Ctx.client.get_file_issue_request(params[:id])

    Templates.emit_with_layout(:file_issue_request_view, {request: file_issue_request, is_readonly: (file_issue_request.fetch('status') == 'FILE_ISSUE_CREATED')},
                               :layout, title: "File Issue Request", context: ['file_issues', 'file_issue_requests'])
  end

  Endpoint.post('/file-issue-requests/update')
    .param(:file_issue_request, FileIssueRequest, "The file issue request to update") do

    errors = Ctx.client.update_file_issue_request(params[:file_issue_request])

    if errors.empty?
      redirect '/file-issue-requests'
    else
      Templates.emit_with_layout(:file_issue_request_view,
                                 {
                                   request: params[:file_issue_request],
                                   errors: errors,
                                   is_readonly: false,
                                 },
                                 :layout, title: "File Issue Request", context: ['file_issues', 'file_issue_requests'])
    end
  end
end
