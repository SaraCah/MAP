class MAPTheApp < Sinatra::Base

  Endpoint.get('/') do
    if Ctx.session[:username]
      # These tags get escaped...
      Templates.emit_with_layout(:hello, {
                                   :name => Ctx.session[:username],
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
      send_file File.absolute_path(JSBundle.filename_for_bundle(filename))
    elsif (match = STATIC_JS_FILES.fetch(filename, nil))
      send_file File.absolute_path(match)
    elsif File.exist?(file = File.join('js', filename))
      send_file File.absolute_path(file)
    elsif File.exist?(file = File.join('buildjs', filename))
      send_file File.absolute_path(file)
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
        send_file File.absolute_path(file)
      else
        [404]
      end
    end
  end

  Endpoint.get('/css/*')
    .param(:cb, String, "Cachebuster (ignored)", optional: true) do

    filename = request.path.split('/').last

    if filename == 'materialize.min.css'
      send_file File.absolute_path('ts/node_modules/materialize-css/dist/css/materialize.min.css')
    elsif File.exist?(file = File.join('css', filename))
      send_file File.absolute_path(file)
    else
      [404]
    end
  end

  Endpoint.get('/favicon.ico') do
    send_file File.absolute_path('favicon.ico')
  end

  Endpoint.get('/webfonts/*') do
    filename = request.path.split('/').last
    if File.exist?(file = File.join('webfonts', filename))
      send_file File.absolute_path(File.absolute_path(file))
    else
      [404]
    end
  end

  Endpoint.get('/mfa') do
    Templates.emit_with_layout(:mfa, {},
                              :layout_blank, title: "Please verify")
  end

  Endpoint.post('/mfa-validate')
    .param(:authcode, String, "Auth Code") do
    if Ctx.client.mfa_validate?(session[:username], params[:authcode])
      session[:api_session_id] = session[:pending_validation_api_session_id]
      redirect '/'
    else
      Templates.emit_with_layout(:mfa, {message: 'Invalid Token. Please try again'},
                                 :layout_blank, title: "Please verify")
    end

  end

  Endpoint.post('/authenticate')
   .param(:username, String, "Username to authenticate")
   .param(:password, String, "Password") do

    rate_limit_key = request.ip || "unknown"

    authentication = Ctx.client.authenticate(params[:username], params[:password], rate_limit_key)

    if authentication.successful?
      session[:username] = params[:username]

      if Ctx.client.has_mfa?(session[:username])
        session[:pending_validation_api_session_id] = authentication.session_id or raise "WOOT"
        redirect '/mfa'
      else
        # TODO Enforce MFA setup?
        session[:api_session_id] = authentication.session_id or raise "WOOT"
        redirect '/'
      end

    elsif authentication.is_user_inactive?
      Templates.emit_with_layout(:login, {username: params[:username], message: "There is an issue with your account please contact discovery@archives.qld.gov.au", delay_seconds: authentication.delay_seconds},
                                 :layout_blank, title: "Please log in")
    else
      Templates.emit_with_layout(:login, {username: params[:username], message: "Login failed", delay_seconds: authentication.delay_seconds},
                                 :layout_blank, title: "Please log in")
    end
  end

  Endpoint.get('/users/new-admin') do
    if Ctx.permissions.is_admin?
      user = UserDTO.new
      user['is_admin'] = true
      Templates.emit(:user_edit, {user: user})
    else
      [404]
    end
  end

  Endpoint.post('/users/assign-to-location')
    .param(:username, String, "The username to assign")
    .param(:location_id, Integer, "The location to assign them to")
    .param(:role, String, "The role to grant") do
    errors = Ctx.client.assign_to_location(params[:username], params[:location_id], params[:role])

    [
      200,
      {'Content-type' => 'text/json'},
      {'errors' => errors}.to_json
    ]
  end

  Endpoint.post('/users/create')
    .param(:user, UserDTO, "The user to create") do
    if Ctx.permissions.is_admin?
      errors = Ctx.client.create_user(params[:user])

      if errors.empty?
        [202]
      else
        Templates.emit(:user_edit, {user: params[:user], errors: errors})
      end
    else
      [404]
    end
  end

  Endpoint.post('/users/create-for-location')
    .param(:user, UserDTO, "The user to create")
    .param(:role, String, "The role to assign")
    .param(:position, String, "The position to assign")
    .param(:location_id, Integer, "The location to link our user to") do

    location = Ctx.client.location_for_edit(params[:location_id])

    unless Ctx.permissions.is_admin?
      unless Ctx.permissions.agency_roles.any? {|role|
               (role.agency_location_id == location.fetch('id') && role.role == 'AGENCY_ADMIN') ||
                 (role.agency_ref == location.fetch('agency_ref') && role.role == 'SENIOR_AGENCY_ADMIN')
             }
        raise "Insufficient Privileges"
      end
    end

    params[:user]['is_admin'] = false

    params[:user]['agency_roles'] = [
      AgencyRoleDTO.new(:agency_ref => location.fetch('agency_ref'),
                        :role => params[:role],
                        :position => params[:position],
                        :agency_location_id => location.fetch('id'))
    ]

    errors = Ctx.client.create_user(params[:user])

    if errors.empty?
      [202]                     # AJAX form success
    else
      Templates.emit(:location_add_user, {
                       user: params[:user],
                       role: params[:role],
                       position: params[:position],
                       location: location,
                       mode: 'new_user',
                       errors: errors
                     })
    end
  end

  # The list of users that the currently logged-in user could conceivably add to
  # a given location.
  Endpoint.get('/users/candidates-for-location')
    .param(:location_id, Integer, "The location in question")
    .param(:q, String, "Search string", optional: true)
    .param(:sort, String, "Sort string", optional: true)
    .param(:page_size, Integer, "Number of users per page")
    .param(:page, Integer, "Page to return") do

    [
      200,
      {'Content-type' => 'text/json'},
      Ctx.client.users_candidates_for_location(params[:location_id],
                                               params[:q],
                                               params[:sort],
                                               params[:page],
                                               params[:page_size]).to_json
    ]
  end



  Endpoint.get('/users/edit')
    .param(:username, String, "Username") do
    unless Ctx.permissions.is_admin?
      # FIXME check permissions
    end

    Templates.emit(:user_edit,
                   user: Ctx.client.user_for_edit(params[:username]))
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
      elsif Ctx.username == params[:user].fetch(:username)
        # Ok! Update your own things (permission changes are ignored in the API)
      else
        # FIXME
        raise "Insufficient Privileges"
      end
    end

    errors = Ctx.client.update_user(params[:user])

    if errors.empty?
      [202]
    else
      Templates.emit(:user_edit, {user: params[:user], errors: errors})
    end
  end

  Endpoint.get('/manage-mfa') do
    secret = Ctx.client.mfa_get_key(session[:username])
    if secret.nil? || secret.empty?
      Templates.emit_with_layout(:manage_mfa_no_key, {}, :layout, title: "Manage MFA")
    else
      totp = ROTP::TOTP.new(secret, issuer: "MAP MFA")
      Templates.emit_with_layout(:manage_mfa, {
          secret: secret,
          regenerate: false,
          qr_code: RQRCode::QRCode.new(totp.provisioning_uri(session[:username])),
          current_token: totp.now
      }, :layout, title: "Manage MFA")
    end

  end

  Endpoint.get('/mfa-new-key') do
    # TODO verify current secret before saving new secret
    # TODO confirm save new secret
    key = ROTP::Base32.random  # returns a 160 bit (32 character) base32 secret. Compatible with Google Authenticator
    Ctx.client.mfa_new_key(session[:username], key)
    redirect '/manage-mfa'
  end

  Endpoint.post('/permissions/remove')
    .param(:user_id, Integer, "User ID")
    .param(:location_id, Integer, "Location ID") do
    Ctx.client.remove_membership(params[:location_id], params[:user_id])

    [202]
  end


  Endpoint.get('/permissions/edit')
    .param(:user_id, Integer, "User ID")
    .param(:location_id, Integer, "Location ID")
    .param(:is_top_level, Integer, "True if this is a top-level location")
    .param(:username, String, "Username")
    .param(:role, String, "User current role")
    .param(:position, String, "User current position") do

    membership = Ctx.client.get_location_membership(params[:location_id], params[:user_id])

    if membership.nil?
      [404]
    else
      matched_role = Ctx.permissions.agency_roles.find {|role|
        role.agency_id == membership.fetch('agency_id') && role.role == 'SENIOR_AGENCY_ADMIN'}

      matched_role ||= Ctx.permissions.agency_roles.find {|role|
        role.agency_location_id == params[:location_id] && role.role == 'AGENCY_ADMIN'
      }

      if matched_role.nil? && !Ctx.permissions.is_admin?
        [404]
      else
        Templates.emit(:location_edit_user_permissions, {
                         user_id: params[:user_id],
                         location_id: params[:location_id],
                         is_top_level: params[:is_top_level] == 1,
                         existing_permissions: membership.fetch('permissions'),
                         available_permissions: Ctx.permissions.is_admin? ? Ctx.client.permission_options.map(&:to_s) : matched_role.permissions,
                         username: params[:username],
                         role: params[:role],
                         position: params[:position],
                         removable_from_location: membership.fetch('removable'),
                       })
      end
    end
  end

  Endpoint.post('/permissions/update')
    .param(:user_id, Integer, "User ID")
    .param(:location_id, Integer, "Location ID")
    .param(:role, String, "Role")
    .param(:position, String, "Position")
    .param(:permissions, [String], "Permissions to set", :optional => true) do

    Ctx.client.set_membership_permissions(params[:location_id], params[:user_id], Array(params[:permissions]), params[:role], params[:position])

    [202]
  end

  Endpoint.get('/logout') do
    Ctx.client.logout

    session[:api_session_id] = nil
    session[:username] = nil

    # [200, "Woot"]
    redirect '/'
  end

  Endpoint.get('/manageable-agencies')
    .param(:q, String, "Search string", optional: true)
    .param(:page, Integer, "Page to return", optional: true) do
    Templates.emit_with_layout(:agencies, {
                                   paged_agencies: Ctx.client.manageable_agencies(params[:page] || 0, params[:q]),
                                   q: params[:q],
                                   params: params,
                                 },
                                 :layout, title: "Agencies", context: ['global', 'agencies'])
  end

  Endpoint.get('/agencies/:agency_ref')
    .param(:agency_ref, String, "Agency ref") do

    if Ctx.permissions.allow_manage_agency?(params[:agency_ref])
      Templates.emit_with_layout(:manage_agency, {
                                   agency_ref: params[:agency_ref],
                                 },
                                 :layout, title: '', context: ['global', 'agencies'])

    else
      [404]
    end
  end


  Endpoint.get('/agencies/:agency_ref/json')
    .param(:agency_ref, String, "Agency ref") do

    if Ctx.permissions.allow_manage_agency?(params[:agency_ref])
      [
        200,
        {'Content-Type' => 'text/json'},
        Ctx.client.agency_for_edit(params[:agency_ref]).to_json
      ]
    else
      [404]
    end
  end

  Endpoint.get('/locations/new')
    .param(:agency_ref, String, "The agency we'll be adding a location to") do
    if Ctx.permissions.allow_manage_locations?
      Templates.emit(:location_edit, {
                       location: AgencyLocationDTO.new(agency_ref: params[:agency_ref]),
                     })
    else
      [404]
    end
  end

  Endpoint.post('/locations/create')
    .param(:location, AgencyLocationDTO, "The agency location to create") do

    return [404] unless Ctx.permissions.allow_manage_locations?

    # unless Ctx.permissions.is_admin?
    #     params[:location]['agency_ref'] = Ctx.get.current_location.agency.id
    # end

    errors = Ctx.client.create_location(params[:location])

    if errors.empty?
      [202]                     # AJAX form success
    else
      Templates.emit(:location_edit, {location: params[:location], errors: errors})
    end
  end

  Endpoint.get('/locations/:id/delete-check')
    .param(:id, Integer, "ID of agency location") do
    if response = Ctx.client.location_delete_check(params[:id])
      Templates.emit(:location_delete_confirmation,
                     {
                       location: response['location'],
                       users_who_would_become_unlinked: response['users_who_would_become_unlinked'],
                     })
    else
      [404]
    end
  end

  Endpoint.post('/locations/:id/delete')
    .param(:id, Integer, "ID of agency location") do
    Ctx.client.location_delete(params[:id])

    [202]
  end

  Endpoint.get('/locations/:id')
    .param(:id, Integer, "ID of agency location") do
    location = Ctx.client.location_for_edit(params[:id])
    if false
      # FIXME check permissions and agency/location etc
      # return [404]
    end

    Templates.emit(:location_edit, {location: location})
  end

  Endpoint.get('/locations/:id/add-user-form')
    .param(:id, Integer, "ID of agency location")
    .param(:mode, String, "One of 'new_user' or 'existing_user'")do
    location = Ctx.client.location_for_edit(params[:id])
    if false
      # FIXME check permissions and agency/location etc
      # return [404]
    end

    Templates.emit(:location_add_user, {location: location,
                                        user: UserDTO.new(username: '', name: ''),
                                        mode: params[:mode]})
  end


  Endpoint.post('/locations/update')
    .param(:location, AgencyLocationDTO, "The location to update") do

    errors = Ctx.client.update_location(params[:location])

    if errors.empty?
      [202]                     # AJAX form success 
    else
      Templates.emit(:location_edit, {location: params[:location], errors: errors})
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
    .param(:status, String, "Status filter", :optional => true)
    .param(:sort, String, "Sort key", :optional => true)
    .param(:page, Integer, "Page to return", optional: true) do

    Templates.emit_with_layout(:transfer_proposals, {
                                 paged_results: Ctx.client.transfer_proposals(params[:page] || 0, params[:status], params[:sort]),
                                 status: params[:status],
                                 sort: params[:sort],
                                 params: params,
                               },
                               :layout, title: "Transfer Proposals", context: ['transfers', 'transfer_proposals'])
  end

  Endpoint.get('/transfer-proposals/new') do
    Templates.emit_with_layout(:transfer_proposal_view, {transfer: TransferProposal.new, is_readonly: false},
                               :layout, title: "New Transfer Proposal", context: ['transfers', 'transfer_proposals'])
  end

  Endpoint.post('/transfer-proposals/create')
    .param(:transfer, TransferProposal, "The transfer to create")
    .param(:save_transfer, Integer, "Set to 1 if the save button was clicked", :optional => true)
    .param(:submit_transfer, Integer, "Set to 1 if the submit button was clicked", :optional => true) do

    if params[:submit_transfer] == 1
      params[:transfer][:status] = TransferProposal::STATUS_ACTIVE
    end

    errors = Ctx.client.create_transfer_proposal(params[:transfer])

    if errors.empty?
      redirect '/transfer-proposals'
    else
      params[:transfer][:status] = TransferProposal::STATUS_INACTIVE

      Templates.emit_with_layout(:transfer_proposal_view, {transfer: params[:transfer], errors: errors, is_readonly: false},
                                 :layout, title: "New Transfer Proposal", context: ['transfers', 'transfer_proposals'])
    end
  end

  Endpoint.post('/file-upload')
    .param(:file, [UploadFile], "Files to upload") do
    if (rejected_files = FileTypeChecker.check(params[:file])) && !rejected_files.empty?
      $LOG.info("Rejecting the following uploaded files due to unrecognised file types: #{rejected_files}")
      [
        415,
        {'Content-type' => 'text/json'},
        {
          'status' => 'REJECTED_FILE_TYPE',
          'rejected_files' => rejected_files.map(&:filename),
        }.to_json
      ]
    else
      files = []
      Ctx.client.store_files(params[:file]).zip(params[:file]).map do |file_key, file|
        files << {
          'key' => file_key,
          'mime_type' => HTTPUtils.sanitise_mime_type(file.mime_type),
          'filename' => file.filename,
        }
      end

      [
        200,
        {'Content-type' => 'text/json'},
        files.to_json
      ]
    end
  end

  Endpoint.get('/transfer-proposals/:id')
    .param(:id, Integer, "ID of transfer proposal") do
    transfer = Ctx.client.get_transfer_proposal(params[:id])
    if false
      # FIXME check permissions and agency/location etc
      # return [404]
    end

    Templates.emit_with_layout(:transfer_proposal_view, {transfer: transfer, is_readonly: (!['ACTIVE', 'INACTIVE'].include?(transfer.fetch('status')))},
                               :layout, title: "Transfer Proposal", context: ['transfers', 'transfer_proposals'])
  end

  Endpoint.post('/transfer-proposals/update')
    .param(:transfer, TransferProposal, "The transfer to update")
    .param(:save_transfer, Integer, "Set to 1 if the save button was clicked", :optional => true)
    .param(:delete_transfer, Integer, "Set to 1 if the delete button was clicked", :optional => true)
    .param(:submit_transfer, Integer, "Set to 1 if the submit button was clicked", :optional => true) do

    if params[:submit_transfer] == 1
      params[:transfer][:status] = TransferProposal::STATUS_ACTIVE
    end

    errors = Ctx.client.update_transfer_proposal(params[:transfer])

    if errors.empty?
      redirect '/transfer-proposals'
    else
      if params[:submit_transfer] == 1
        params[:transfer][:status] = TransferProposal::STATUS_INACTIVE
      end

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

  Endpoint.post('/transfer-proposals/:id/delete')
    .param(:id, Integer, "ID of transfer proposal to delete") do

    # FIXME check permissions or else
    Ctx.client.delete_transfer_proposal(params[:id])

    redirect '/transfer-proposals'
  end

  Endpoint.get('/file-download')
    .param(:key, String, "File key")
    .param(:mime_type, String, "MIME type of file")
    .param(:filename, String, "Filename") do
    [
      200,
      {
        'Content-Type' => HTTPUtils.sanitise_mime_type(params[:mime_type]),
        'Content-Disposition' => "attachment; filename=#{params[:filename]}"
      },
      Ctx.client.stream_file(params[:key])
    ]
  end

  Endpoint.get('/transfers')
    .param(:status, String, "Status filter", :optional => true)
    .param(:sort, String, "Sort key", :optional => true)
    .param(:page, Integer, "Page to return", optional: true) do

    Templates.emit_with_layout(:transfers, {
                                 paged_results: Ctx.client.transfers(params[:page] || 0, params[:status], params[:sort]),
                                 status: params[:status],
                                 sort: params[:sort],
                                 params: params,
                               },
                               :layout, title: "Transfers", context: ['transfers', 'initiated_transfers'])
  end

  Endpoint.get('/get-messages')
    .param(:handle_id, Integer, "Handle ID") do

    # FIXME permissions check!
    [
      200,
      {'Content-type' => 'text/json'},
      {
        'messages' => Ctx.client.get_messages(params[:handle_id]),
      }.to_json
    ]
  end

  Endpoint.post('/post-message')
    .param(:message, String, "Message")
    .param(:handle_id, Integer, "Handle ID") do

    # FIXME check permissions, error handling

    Ctx.client.post_message(params[:handle_id], params[:message])

    [
      200,
      {'Content-type' => 'text/json'},
      {'status' => 'success'}.to_json
    ]
  end

  Endpoint.get('/transfers/template') do
    send_file(File.absolute_path('static/transfer_template.xlsx'),
              :disposition => 'attachment',
              :filename => 'qsa_agency_transfer_template.xlsx',
              :type => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
  end

  Endpoint.get('/transfers/:id/report')
      .param(:id, Integer, "ID of transfer") do
    Ctx.client.stream_transfer_report(params[:id], "transfer_report.T#{params[:id]}.#{Date.today.iso8601}.csv")
  end

  Endpoint.get('/transfers/:id')
    .param(:id, Integer, "ID of transfer") do
    transfer = Ctx.client.get_transfer(params[:id])
    if false
      # FIXME check permissions and agency/location etc
      # return [404]
    end

    Templates.emit_with_layout(:transfer_view, {transfer: transfer, is_readonly: (!transfer.active?)},
                               :layout, title: "Transfer", context: ['transfers', 'initiated_transfers'])
  end

  Endpoint.post('/transfers/update')
    .param(:transfer, Transfer, "The transfer to update") do

    # FIXME check permissions

    errors = Ctx.client.update_transfer(params[:transfer])

    if errors.empty?
      redirect '/transfers'
    else
      transfer = Ctx.client.get_transfer(params[:transfer].fetch('id'))
      transfer['files'] = params[:transfer].fetch('files')

      Templates.emit_with_layout(:transfer_view,
                                 {
                                   transfer: transfer,
                                   errors: errors,
                                   is_readonly: false,
                                 },
                                 :layout, title: "Transfer", context: ['transfers', 'initiated_transfers'])
    end
  end

  Endpoint.post('/transfers/:id/cancel')
    .param(:id, Integer, "The ID of the transfer to cancel") do

    # FIXME check permissions

    Ctx.client.cancel_transfer(params[:id])

    redirect '/transfers'
  end

  Endpoint.get('/import-validate')
    .param(:key, String, "The file key to validate") do
    result = Ctx.client.import_validate(params[:key])

    [
      200,
      {'Content-type' => 'text/json'},
      result.to_json
    ]
  end

  Endpoint.get('/file-issue-requests')
    .param(:sort, String, "Sort key", :optional => true)
    .param(:physical_request_status, String, "Physical request status filter", :optional => true)
    .param(:digital_request_status, String, "Digital request status filter", :optional => true)
    .param(:page, Integer, "Page to return", optional: true) do

    Templates.emit_with_layout(:file_issue_requests, {
                                 paged_results: Ctx.client.file_issue_requests(params[:page] || 0, params[:digital_request_status], params[:physical_request_status], params[:sort]),
                                 digital_request_status: params[:digital_request_status],
                                 physical_request_status: params[:physical_request_status],
                                 sort: params[:sort],
                                 params: params,
                               },
                               :layout, title: "File Issue Requests", context: ['file_issues', 'file_issue_requests'])
  end

  Endpoint.get('/file-issue-requests/new')
    .param(:record_ref, String, "Populate request items from this record", optional: true) do

    request = FileIssueRequest.new
    resolved_representations = []

    if params[:record_ref]
      record = Ctx.client.find_record(params[:record_ref])
      representation_refs_for_record = []
      if record && record.fetch('primary_type') == 'archival_object'
        all_representations = record.fetch('all_representations', [])
        unless all_representations.empty?
          representation_refs_for_record = all_representations.map do |uri|
            if uri =~ /^.*(digital_representation|physical_representation)s\/([0-9]+)$/
              "#{$1}:#{$2}"
            end
          end.compact
        end
      elsif record && record.fetch('types',[]).include?('representation')
        representation_refs_for_record = [params[:record_ref]]
      end

      Ctx.client.resolve_representations(representation_refs_for_record).map do |representation|
        if representation.fetch('file_issue_allowed', nil) == 'allowed_true'
          request.fetch('items') << FileIssueRequestItem.from_solr_doc(representation)
          resolved_representations << representation
        end
      end
    end

    Templates.emit_with_layout(:file_issue_request_view, {request: request, resolved_representations: resolved_representations, is_readonly: false},
                               :layout, title: "New Request", context: ['file_issues', 'file_issue_requests'])
  end

  Endpoint.post('/file-issue-requests/create')
    .param(:file_issue_request, FileIssueRequest, "The file issue request to create")
    .param(:submit_file_issue_request, Integer, "Set to 1 if the submit button was clicked", :optional => true) do

    params[:file_issue_request][:draft] = params[:submit_file_issue_request] != 1

    errors = Ctx.client.create_file_issue_request(params[:file_issue_request])

    if errors.empty?
      redirect '/file-issue-requests'
    else
      if params[:submit_file_issue_request] == 1
        params[:file_issue_request][:draft] = true
      end

      resolved_representations = Ctx.client.resolve_representations(params[:file_issue_request].fetch('items').collect{|item| item.fetch('record_ref')})
      Templates.emit_with_layout(:file_issue_request_view, {request: params[:file_issue_request], resolved_representations: resolved_representations, errors: errors, is_readonly: false},
                                 :layout, title: "New Request", context: ['file_issues', 'file_issue_requests'])
    end
  end

  Endpoint.get('/file-issue-requests/:id')
    .param(:id, Integer, "ID of file issue request") do
    file_issue_request = Ctx.client.get_file_issue_request(params[:id])
    resolved_representations = Ctx.client.resolve_representations(file_issue_request.fetch('items').collect{|item| item.fetch('record_ref')}) 

    digital_request_quote = nil
    physical_request_quote = nil

    if file_issue_request.show_digital_quote?
      digital_request_quote = Ctx.client.get_file_issue_digital_quote(file_issue_request.fetch('id'))
    end

    if file_issue_request.show_physical_quote?
      physical_request_quote = Ctx.client.get_file_issue_physical_quote(file_issue_request.fetch('id'))
    end

    Templates.emit_with_layout(:file_issue_request_view, {
                                 request: file_issue_request,
                                 resolved_representations: resolved_representations,
                                 is_readonly: !file_issue_request.can_edit?,
                                 digital_request_quote: digital_request_quote,
                                 physical_request_quote: physical_request_quote,
                               },
                               :layout, title: "File Issue Request", context: ['file_issues', 'file_issue_requests'])
  end

  Endpoint.post('/file-issue-requests/update')
    .param(:file_issue_request, FileIssueRequest, "The file issue request to update")
    .param(:submit_file_issue_request, Integer, "Set to 1 if the submit button was clicked", :optional => true) do

    orig_draft_status = params[:file_issue_request].fetch(:draft)

    if orig_draft_status
      params[:file_issue_request][:draft] = params[:submit_file_issue_request] != 1
    end

    errors = params[:file_issue_request].validate.map {|e|
      e.map {|k, v| [k.to_s, v]}.to_h
    }

    if errors.empty?
      errors = Ctx.client.update_file_issue_request(params[:file_issue_request])
    end

    if errors.empty?
      redirect '/file-issue-requests'
    else
      params[:file_issue_request][:draft] = orig_draft_status
      Templates.emit_with_layout(:file_issue_request_view,
                                 {
                                   request: params[:file_issue_request],
                                   errors: errors,
                                   is_readonly: false,
                                 },
                                 :layout, title: "File Issue Request", context: ['file_issues', 'file_issue_requests'])
    end
  end

  Endpoint.post('/file-issue-requests/:id/accept')
    .param(:id, Integer, "ID of file issue request")
    .param(:lock_version, Integer, "Lock version of the file issue request")
    .param(:request_type, String, "Request type this action applies to") do
    Ctx.client.accept_file_issue_request(params[:id],
                                         params[:lock_version],
                                         params[:request_type])

    redirect "/file-issue-requests/#{params[:id]}"
  end

  Endpoint.post('/file-issue-requests/:id/cancel')
    .param(:id, Integer, "ID of file issue request")
    .param(:lock_version, Integer, "Lock version of the file issue request")
    .param(:request_type, String, "Request type this action applies to", optional: true) do
    Ctx.client.cancel_file_issue_request(params[:id],
                                         params[:lock_version],
                                         params[:request_type])

    redirect "/file-issue-requests/#{params[:id]}"
  end

  Endpoint.post('/file-issue-requests/:id/delete')
    .param(:id, Integer, "ID of file issue request to delete") do

    # FIXME check permissions or else
    Ctx.client.delete_file_issue_request(params[:id])

    redirect '/file-issue-requests'
  end

  Endpoint.get('/resolve/representations')
    .param(:ref, [String], "Record refs to resolve") do
    [
      200,
      {'Content-type' => 'text/json'},
      Ctx.client.resolve_representations(params[:ref]).to_json
    ]
  end

  Endpoint.get('/file-issues')
    .param(:sort, String, "Sort key", :optional => true)
    .param(:issue_type, String, "Issue type filter", :optional => true)
    .param(:status, String, "Status filter", :optional => true)
    .param(:page, Integer, "Page to return", optional: true) do

    Templates.emit_with_layout(:file_issues, {
                                 paged_results: Ctx.client.file_issues(params[:page] || 0, params[:issue_type], params[:status], params[:sort]),
                                 issue_type: params[:issue_type],
                                 status: params[:status],
                                 sort: params[:sort],
                                 params: params,
                               },
                               :layout, title: "File Issues", context: ['file_issues', 'initiated_file_issues'])
  end

  Endpoint.get('/file-issues/:id')
    .param(:id, Integer, "ID of file issue") do
    file_issue = Ctx.client.get_file_issue(params[:id])
    resolved_representations = Ctx.client.resolve_representations(file_issue.fetch('items').collect{|item| item.fetch('record_ref')})

    Templates.emit_with_layout(:file_issue_view, {file_issue: file_issue, resolved_representations: resolved_representations, is_readonly: true},
                               :layout, title: "File Issue", context: ['file_issues', 'initiated_file_issues'])
  end

  Endpoint.get('/file-issue-delivery')
    .param(:filename, String, "Suggested filename", optional: true)
    .param(:token, String, "Redemption token") do
    begin
      Ctx.client.stream_file_issue(params[:token], params[:filename])
    rescue MAPAPIClient::FileIssueExpired => e
      # Some helpful template (410 gone baby)
      [
        410,
        {},
        Templates.emit_with_layout(:file_issue_download_expired, {},
                                   :layout, title: "Download expired")

      ]
    rescue MAPAPIClient::FileIssueNotFound => e
      # Something went wrong... 404?
      [
        404,
        {},
        Templates.emit_with_layout(:file_issue_download_missing, {},
                                   :layout, title: "Download missing")

      ]
    rescue MAPAPIClient::FileIssueNotDispatched => e
      # Something went wrong... 404?
      [
        404,
        {},
        Templates.emit_with_layout(:file_issue_not_dispatched, {},
                                   :layout, title: "Download not yet available")

      ]
    end
  end

  Endpoint.get('/file-issue-fee-schedule') do
    chargeable_services = Ctx.client.get_file_issue_fee_schedule

    Templates.emit_with_layout(:fee_schedule, {chargeable_services: chargeable_services},
                               :layout, title: "Fee Schedule", context: ['file_issues', 'fee_schedule'])
  end

  Endpoint.get('/file-issue-report') do
    Templates.emit_with_layout(:file_issue_report, {},
                               :layout, title: "File Issue Report", context: ['file_issues', 'file_issue_report'])
  end

  Endpoint.post('/file-issue-report/download')
    .param(:start_date, String, "Report start date", :optional => true)
    .param(:end_date, String, "Report end date", :optional => true) \
  do
    Ctx.client.stream_file_issue_report(params[:start_date], params[:end_date], "file_issue_report_#{Date.today.iso8601}.csv")
  end

  Endpoint.get('/notifications') do
    [
      200,
      {'Content-type' => 'text/json'},
      Ctx.client.notifications.to_json
    ]
  end

  TYPE_LABELS = {
    'resource' => 'Series',
    'archival_object' => 'Record',
    'physical_representation' => 'Physical Representation',
    'digital_representation' => 'Digital Representation',
  }

  def label_for_field_value(field, value, response)
    if field == 'primary_type'
      TYPE_LABELS.fetch(value)
    elsif field == 'creating_agency'
      response['agency_titles_by_ref'].fetch(value, value)
    else
      value
    end
  end

  Endpoint.get('/controlled-records')
    .param(:q, String, "Query string", :optional => true)
    .param(:filters, String, "Filters to apply [[field1, val1], [field2, val2]]", :optional => true)
    .param(:start_date, String, "Start of date range", :optional => true)
    .param(:end_date, String, "End of date range", :optional => true)
    .param(:sort, String, "Sort key", :optional => true)
    .param(:page, Integer, "Page to fetch")
    .param(:page_size, Integer, "Elements per page") do

    # Clamp to a sensible maximum
    page_size = [params[:page_size], 200].min

    controlled_records = Ctx.client
                           .get_controlled_records(params[:q],
                                                   JSON.parse(params[:filters] || '[]'),
                                                   (params[:sort] || "relevance"),
                                                   params[:start_date], params[:end_date],
                                                   params[:page], page_size)

    # Map types to their labels
    controlled_records.fetch('results', []).each do |result|
      result['type'] = label_for_field_value('primary_type', result.fetch('primary_type'), controlled_records)

      Array(result['representations_json']).each do |representation|
        representation['type'] = label_for_field_value('primary_type', representation.fetch('primary_type'), controlled_records)
      end
    end

    # Turn facets from ['val1', count1, 'val2', count2, ...] into an array of maps
    controlled_records['facets'] = controlled_records.fetch('facets', {}).map {|field, facet_arr|
      [field,
       facet_arr.each_slice(2).map {|value, count|
         {
           field: field,
           value: value,
           label: label_for_field_value(field, value, controlled_records),
           count: count,
         }
       }
      ]
    }.to_h

    [
      200,
      {'Content-type' => 'text/json'},
      controlled_records.to_json
    ]
  end

  Endpoint.get('/records') do
    Templates.emit_with_layout(
      :records, {
        :agency => Ctx.client.get_current_agency, 
        :location => Ctx.get.current_location
      },
      :layout,
      title: "Controlled Records",
      context: ['records', 'controlled_records'])
  end

  Endpoint.get('/search-requests')
    .param(:sort, String, "Sort key", :optional => true)
    .param(:status, String, "Status filter", :optional => true)
    .param(:page, Integer, "Page to return", optional: true) do

    Templates.emit_with_layout(
      :search_requests,
      {
        paged_results: Ctx.client.search_requests(params[:page] || 0, params[:status], params[:sort]),
        sort: params[:sort],
        status: params[:status],
        params: params,
      },
      :layout,
      title: "Search Requests",
      context: ['records', 'search_requests'])
  end

  Endpoint.get('/search-requests/new')
    .param(:record_ref, String, "Populate request items from this record", optional: true) do

    request = SearchRequest.new

    Templates.emit_with_layout(:search_request_view, {request: request, is_readonly: false},
                               :layout, title: "New Search Request", context: ['records', 'search_requests'])
  end

  Endpoint.post('/search-requests/create')
    .param(:search_request, SearchRequest, "The search request to create")
    .param(:save_search_request, Integer, "Set to 1 if the save button was clicked", :optional => true)
    .param(:submit_search_request, Integer, "Set to 1 if the submit button was clicked", :optional => true) do

    params[:search_request][:draft] = params[:submit_search_request] != 1

    errors = Ctx.client.create_search_request(params[:search_request])

    if errors.empty?
      redirect '/search-requests'
    else
      Templates.emit_with_layout(:search_request_view, {request: params[:search_request], errors: errors, is_readonly: false},
                                 :layout, title: "New Request", context: ['records', 'search_requests'])
    end
  end

  Endpoint.get('/search-requests/:id')
    .param(:id, Integer, "ID of search request") do
    search_request = Ctx.client.get_search_request(params[:id])

    quote = nil

    if search_request.has_quote?
      quote = Ctx.client.get_search_request_quote(search_request.fetch('id'))

      if quote.nil? || quote.fetch('issued_date', nil).nil?
        quote = nil
      end
    end

    Templates.emit_with_layout(
      :search_request_view,
      {
        request: search_request,
        is_readonly: !search_request.can_edit?,
        quote: quote,
      },
      :layout, title: "Search Request", context: ['records', 'search_requests'])
  end

  Endpoint.post('/search-requests/update')
    .param(:search_request, SearchRequest, "The search request to update")
    .param(:save_search_request, Integer, "Set to 1 if the save button was clicked", :optional => true)
    .param(:submit_search_request, Integer, "Set to 1 if the submit button was clicked", :optional => true) do

    orig_draft_status = params[:search_request].fetch(:draft)
    params[:search_request][:draft] = params[:submit_search_request] != 1

    errors = Ctx.client.update_search_request(params[:search_request])

    if errors.empty?
      redirect '/search-requests'
    else
      params[:search_request][:draft] = orig_draft_status
      Templates.emit_with_layout(:search_request_view,
                                 {
                                   request: params[:search_request],
                                   errors: errors,
                                   is_readonly: false,
                                 },
                                 :layout, title: "Search Request", context: ['file_issues', 'search_requests'])
    end
  end

  Endpoint.post('/search-requests/:id/cancel')
    .param(:id, Integer, "The ID of the search request to cancel")
    .param(:lock_version, Integer, "The lock version search request to cancel") do

    Ctx.client.cancel_search_request(params[:id], params[:lock_version])

    redirect '/search-requests'
  end

  Endpoint.get('/search-request-fee-schedule') do
    chargeable_services = Ctx.client.get_search_request_fee_schedule

    Templates.emit_with_layout(:fee_schedule, {chargeable_services: chargeable_services},
                               :layout, title: "Fee Schedule", context: ['records', 'fee_schedule'])
  end

  Endpoint.get('/system') do
    if Ctx.permissions.is_admin?
      Templates.emit_with_layout(:manage_system, {},
                                 :layout, title: "Manage System", context: ['global', 'system'])
    else
      [404]
    end
  end

  Endpoint.get('/system/json') do
    if Ctx.permissions.is_admin?
      [
        200,
        {'Content-Type' => 'text/json'},
        {
          'administrators' => Ctx.client.get_system_admins
        }.to_json
      ]
    else
      [404]
    end
  end

  Endpoint.get('/reading-room-requests')
    .param(:sort, String, "Sort key", :optional => true)
    .param(:status, String, "Status filter", :optional => true)
    .param(:date_required, String, "Date required filter", :optional => true)
    .param(:page, Integer, "Page to return", optional: true) do

    results = Ctx.client.reading_room_requests(params[:page] || 0, params[:status], params[:date_required], params[:sort])
    resolved_representations = {}
    Ctx.client.resolve_representations(results.results.map{|result| result.fetch('record_ref')}).each do |representation|
      resolved_representations[representation.fetch('ref')] = representation
    end

    Templates.emit_with_layout(:reading_room_requests, {
        paged_results: results,
        status: params[:status],
        sort: params[:sort],
        date_required: params[:date_required],
        params: params,
        resolved_representations: resolved_representations,
      },
      :layout, title: "Reading Room Requests", context: ['reading_room_requests'])
  end

  Endpoint.get('/reading-room-requests/new') do
    request = ReadingRoomRequest.new

    Templates.emit_with_layout(:reading_room_request_view, {request: request, requested_items: [], is_readonly: false},
                               :layout, title: "New Reading Room Request", context: ['reading_room_requests'])
  end

  Endpoint.post('/reading-room-requests/create')
    .param(:reading_room_request, ReadingRoomRequest, "The reading room request to create")
    .param(:requested_item, [String], "Ids of the representations requested")
    .param(:submit_reading_room_request, Integer, "Set to 1 if the submit button was clicked") do

    errors = Ctx.client.create_reading_room_requests(params[:reading_room_request], params[:requested_item])

    if errors.empty?
      redirect '/reading-room-requests'
    else
      resolved_representations = Ctx.client.resolve_representations(params[:requested_item])
      Templates.emit_with_layout(:reading_room_request_view,
                                 {
                                   request: params[:reading_room_request],
                                   requested_items: params[:requested_item].map{|id| {record_ref: id}},
                                   resolved_representations: resolved_representations,
                                   errors: errors,
                                   is_readonly: false
                                 },
                                 :layout, title: "New Reading Room Request", context: ['reading_room_requests'])
    end
  end

  Endpoint.get('/reading-room-requests/:id')
    .param(:id, Integer, "ID of request") do
    reading_room_request = Ctx.client.get_reading_room_request(params[:id])
    resolved_representations = Ctx.client.resolve_representations([reading_room_request.fetch('record_ref')])
    requested_items = [{record_ref: reading_room_request.fetch('record_ref')}]

    Templates.emit_with_layout(:reading_room_request_view,
                               {
                                 request: reading_room_request,
                                 resolved_representations: resolved_representations,
                                 requested_items: requested_items,
                                 is_readonly: true
                               },
                               :layout, title: "Reading Room Request", context: ['reading_room_requests'])
  end

  Endpoint.post('/reading-room-requests/:id/cancel')
    .param(:id, Integer, "ID of request")
    .param(:lock_version, Integer, "Lock version of the request") do
    Ctx.client.cancel_reading_room_request(params[:id],
                                           params[:lock_version])

    redirect "/reading-room-requests/#{params[:id]}"
  end
end
