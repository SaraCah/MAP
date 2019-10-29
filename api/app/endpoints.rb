class MAPTheAPI < Sinatra::Base

  # Enforce a limit on how many validations are in flight at a time.  Keep
  # memory under control.
  VALIDATION_SEMAPHORE = java.util.concurrent.Semaphore.new(AppConfig[:max_concurrent_xlsx_validations])

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
    auth_result = DBAuth.authenticate(params[:username], params[:password])

    if auth_result.success?
      json_response(authenticated: true,
                    session: Sessions.create_session(params[:username]))
    else
      json_response(authenticated: false,
                    delay_seconds: auth_result.delay_seconds)
    end
  end

  Endpoint.post('/has-mfa', needs_session: false)
    .param(:username, String, "Username") do
    user_id = Users.id_for_username(params[:username])
    if Mfa.has_key?(user_id)
      json_response(has_key: true)
    else
      json_response(has_key: false)
    end
  end

  Endpoint.post('/mfa-validate', needs_session: false)
    .param(:username, String, "Username")
    .param(:authcode, String, "Authcode") do
    user_id = Users.id_for_username(params[:username])
    if Mfa.key_verified(user_id, params[:authcode]).nil?
      json_response(validated: false)
    else
      json_response(validated: true)
    end
  end

  Endpoint.post('/mfa-get-key', needs_session: false)
      .param(:username, String, "Username") do
    user_id = Users.id_for_username(params[:username])
    key = Mfa.get_key(user_id)
    json_response(key: key)
  end

  Endpoint.post('/mfa-new-key')
    .param(:username, String, "Username")
    .param(:key, String, "Key") do
      user_id = Users.id_for_username(params[:username])
      # TODO error handling
      Mfa.save_key(user_id, params[:key])
      # TODO save the key to the database.
      json_response(status: 'ok')
    end

  Endpoint.post('/users/create')
    .param(:user, UserDTO, "User") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_create_users?(Ctx.get.current_location ? Ctx.get.current_location.agency_ref : nil)
      if (errors = params[:user].validate).empty?
        if !(errors = Users.validate_roles(params[:user])).empty?
          json_response(errors: errors)
        elsif (errors = Users.create_from_dto(params[:user])).empty?
          json_response(status: 'created')
        else
          json_response(errors: errors)
        end
      else
        json_response(errors: errors) unless errors.empty?
      end
    else
      Ctx.log_bad_access("attempted to create user")
      [404]
    end
  end

  # The list of users that the currently logged-in user could conceivably add to
  # a given location.
  Endpoint.get('/users/candidates-for-location')
    .param(:location_id, Integer, "The location in question")
    .param(:q, String, "Search string", optional: true)
    .param(:sort, String, "Sort string", optional: true)
    .param(:page_size, Integer, "Users to return per page")
    .param(:page, Integer, "Page to return") do

    json_response(Locations.candidates_for_location(Ctx.get.permissions,
                                                    params[:location_id],
                                                    params[:q],
                                                    params[:sort],
                                                    params[:page],
                                                    params[:page_size]))
  end

  Endpoint.post('/users/update')
    .param(:user, UserDTO, "User") do
    if Ctx.user_logged_in?
      existing_user = Users.dto_for(params[:user].fetch('username'))
      if existing_user && Ctx.get.permissions.can_edit_user?(existing_user)
        if (errors = params[:user].validate).empty?
          if (errors = Users.update_from_dto(params[:user])).empty?
            json_response(status: 'updated')
          else
            json_response(errors: errors)
          end
        else
          json_response(errors: errors) unless errors.empty?
        end
      else
        Ctx.log_bad_access("attempted to update user #{params[:user]}")
        [404]
      end
    else
      Ctx.log_bad_access("anonymous access attempted to update user #{params[:user]}")
      [404]
    end
  end

  Endpoint.get('/search/get_record')
    .param(:record_ref, String, "Record reference (SOLR doc id)") do
    # FIXME: Users.permissions_for_user -> Ctx.get.permissions?
    permissions = Users.permissions_for_user(Ctx.username)
    record = Search.get_record(params[:record_ref], permissions)
    if (record)
      json_response(record)
    else
      [404]
    end
  end

  Endpoint.get('/my-permissions') do
    if Ctx.user_logged_in?
    # FIXME: Users.permissions_for_user -> Ctx.get.permissions?
      json_response(Users.permissions_for_user(Ctx.username))
    else
      json_response([])
    end
  end

  Endpoint.post('/locations/create')
    .param(:location, AgencyLocationDTO, "Location") do
    if Ctx.user_logged_in?
      if (errors = params[:location].validate).empty?
        if Ctx.get.permissions.can_manage_locations?(params[:location].fetch('agency_ref'))
          if (errors = Locations.create_location_from_dto(params[:location])).empty?
            json_response(status: 'created')
          else
            json_response(errors: errors)
          end
        else
          Ctx.log_bad_access("user attempted to create location")
          json_response(errors: [{code: 'INSUFFICIENT_PRIVILEGES', field: 'agency_ref'}])
        end
      else
        json_response(errors: errors)
      end
    else
      [403]
    end
  end

  Endpoint.get('/locations/:id/delete-check')
    .param(:id, Integer, "The location ID to check") do
    location = Locations.dto_for(params[:id])

    if Ctx.get.permissions.can_manage_locations?(location.fetch('agency_ref'))
      json_response("location" => location,
                    "users_who_would_become_unlinked" => Locations.list_exclusively_linked_users(params[:id]))
    else
      Ctx.log_bad_access("user called delete-check on an agency they don't manage")
      [403]
    end
  end

  Endpoint.post('/locations/:id/delete')
    .param(:id, Integer, "The location ID to check") do
    location = Locations.dto_for(params[:id])

    if Ctx.get.permissions.can_manage_locations?(location.fetch('agency_ref'))
      Locations.delete(params[:id])
      json_response("status" => "deleted")
    else
      Ctx.log_bad_access("user attempted to delete agency")
      [403]
    end
  end

  Endpoint.get('/locations/:id')
    .param(:id, Integer, "ID of agency location") do
    if Ctx.user_logged_in?
      location = Locations.dto_for(params[:id])
      if Ctx.get.permissions.can_manage_locations?(location.fetch('agency_ref'))
        json_response(location.to_hash)
      else
        Ctx.log_bad_access("user tried to access location they don't have access to")
        [404]
      end
    else
      Ctx.log_bad_access("anonymous user tried to access location they don't have access to")
      [404]
    end
  end


  Endpoint.post('/locations/update')
    .param(:location, AgencyLocationDTO, "Location to update") do
    if (errors = params[:location].validate).empty?
      if Ctx.get.permissions.can_manage_locations?(params[:location].fetch('agency_ref'))
        if (errors = Locations.update_location_from_dto(params[:location])).empty?
          json_response(status: 'updated')
        else
          json_response(errors: errors)
        end
      else
        Ctx.log_bad_access("user tried to update location they don't have access to")
        json_response(errors: [{code: 'INSUFFICIENT_PRIVILEGES', field: 'agency_ref'}])
      end
    else
      json_response(errors: errors)
    end
  end

  Endpoint.get('/location-membership')
    .param(:user_id, Integer, "User ID")
    .param(:location_id, Integer, "Location ID") do

    membership = Permissions.get_location_membership(params[:user_id], params[:location_id])

    if membership
      json_response(membership)
    else
      [404]
    end
  end

  Endpoint.post('/remove-membership')
    .param(:user_id, Integer, "User ID")
    .param(:location_id, Integer, "Location ID") do

    Permissions.remove_membership(params[:user_id], params[:location_id])
    json_response({})
  end

  Endpoint.post('/location-membership/set-permissions')
    .param(:user_id, Integer, "User ID")
    .param(:location_id, Integer, "Location ID")
    .param(:role, String, "Role")
    .param(:position, String, "Position")
    .param(:permissions, [String], "Permissions to set", :optional => true) do
    membership = Permissions.set_membership_permissions(params[:user_id], params[:location_id], Array(params[:permissions]), params[:role], params[:position])

    if membership
      json_response({})
    else
      [403]
    end
  end

  Endpoint.get('/my-location') do
    if Ctx.user_logged_in?
      json_response(Ctx.get.current_location)
    else
      json_response({})
    end
  end


  Endpoint.get('/my-locations') do
    if Ctx.user_logged_in?
      json_response(Locations.locations_for_user)
    else
      json_response({})
    end
  end


  Endpoint.get('/my-agency') do
    if Ctx.user_logged_in? && Ctx.get.current_location
      agent_summary = Agencies.get_summary(Ctx.get.current_location.agency_id)
      json_response(agent_summary)
    else
      json_response({})
    end
  end
  Endpoint.get('/agencies-manageable-by-current-user')
    .param(:q, String, "Query string", :optional => true)
    .param(:page, Integer, "Page to fetch (zero-indexed)") do
    json_response(Agencies.manageable_for_permissions(Ctx.get.permissions, q: params[:q], page: params[:page]))
  end


  Endpoint.get('/agency-for-edit')
    .param(:agency_ref, String, "The agency reference") do
    if Ctx.get.permissions.can_manage_locations?(params[:agency_ref])
      json_response(Agencies.for_edit(params[:agency_ref]))
    else
      Ctx.log_bad_access("user tried to fetch agency for edit without having access")
      [403]
    end
  end


  Endpoint.get('/controlled-records')
    .param(:q, String, "Query string", :optional => true)
    .param(:filters, String, "Filters to apply [[field1, val1], [field2, val2]]", :optional => true)
    .param(:sort, String, "Sort key", :optional => true)
    .param(:start_date, DateString, "Start of date range", :optional => true)
    .param(:end_date, DateString, "End of date range", :optional => true)
    .param(:page, Integer, "Page to fetch (zero-indexed)")
    .param(:page_size, Integer, "Size of each page") do
    if Ctx.user_logged_in? && Ctx.get.current_location
      permissions = Users.permissions_for_user(Ctx.username)
      json_response(Search.controlled_records(permissions,
                                              params[:q],
                                              JSON.parse(params[:filters] || '[]'),
                                              (params[:sort] || "relevance"),
                                              params[:start_date], params[:end_date],
                                              params[:page], params[:page_size]))
    else
      json_response([])
    end
  end

  Endpoint.post('/set-location')
    .param(:agency_id, Integer, "Agency Id")
    .param(:location_id, Integer, "Location Id") do

    if Ctx.get.permissions.has_role_for_location?(params[:agency_id], params[:location_id])
      Ctx.get.set_location(params[:agency_id], params[:location_id])
      json_response(status: 'ok')
    else
      Ctx.log_bad_access("user tried to set a location they don't belong to")
      [403]
    end
  end

  Endpoint.get('/user-for-edit')
    .param(:username, String, "Username to authenticate") do
    if Ctx.user_logged_in?
      user = Users.dto_for(params[:username])
      if user && Ctx.get.permissions.can_edit_user?(user)
        json_response(user.to_hash)
      else
        Ctx.log_bad_access("user tried to edit user they don't have permission for (username: #{params[:username]})")
        [404]
      end
    else
      Ctx.log_bad_access("anonymous user tried to edit user (username: #{params[:username]})")
      [404]
    end
  end

  Endpoint.get('/transfer-proposals')
    .param(:status, String, "Status filter", :optional => true)
    .param(:sort, String, "Sort key", :optional => true)
    .param(:page, Integer, "Page to return") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_transfers?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      json_response(Transfers.proposals(params[:page], AppConfig[:page_size], params[:status], params[:sort]))
    else
      Ctx.log_bad_access("user tried to access transfer proposals without permission")
      [404]
    end
  end

  Endpoint.get('/transfers')
    .param(:status, String, "Status filter", :optional => true)
    .param(:sort, String, "Sort key", :optional => true)
    .param(:page, Integer, "Page to return") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_transfers?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      json_response(Transfers.transfers(params[:page], AppConfig[:page_size], params[:status], params[:sort]))
    else
      Ctx.log_bad_access("user tried to access transfers without permission")
      json_response([])
    end
  end

  Endpoint.post('/transfer-proposals/create')
    .param(:transfer, TransferProposal, "Transfer to create") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_transfers?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      if (errors = params[:transfer].validate).empty?
        if (errors = Transfers.create_proposal_from_dto(params[:transfer])).empty?
          json_response(status: 'created')
        else
          json_response(errors: errors)
        end
      else
        json_response(errors: errors)
      end
    else
      Ctx.log_bad_access("user tried to create transfer proposal without permission")
      [404]
    end
  end

  Endpoint.post('/store-files')
    .param(:file, [UploadFile], "Files to store") do
    if Ctx.user_logged_in?
      json_response(params[:file].map {|file| ByteStorage.get.store(file.tmp_file)})
    else
      Ctx.log_bad_access("anonymous user tried to store file")
      [404]
    end
  end

  Endpoint.get('/transfer-proposals/:id')
    .param(:id, Integer, "ID of transfer proposal") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_transfers?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      transfer = Transfers.proposal_dto_for(params[:id])
      if transfer && Ctx.get.permissions.can_manage_transfers?(transfer.fetch('agency_id'), transfer.fetch('agency_location_id'))
        json_response(transfer.to_hash)
      else
        Ctx.log_bad_access("user tried to fetch transfer without permission")
        [404]
      end
    else
      [404]
    end
  end

  Endpoint.post('/transfer-proposals/update')
    .param(:transfer, TransferProposal, "Transfer to update") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_transfers?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      if (errors = params[:transfer].validate).empty?
        existing_transfer = Transfers.proposal_dto_for(params[:transfer].fetch('id'))
        if existing_transfer && Ctx.get.permissions.can_manage_transfers?(existing_transfer.fetch('agency_id'), existing_transfer.fetch('agency_location_id'))
          if (errors = Transfers.update_proposal_from_dto(params[:transfer])).empty?
            json_response(status: 'updated')
          else
            json_response(errors: errors)
          end
        else
          Ctx.log_bad_access("user tried to update transfer proposal without permission for location")
          json_response(errors: [{code: 'INSUFFICIENT_PRIVILEGES', field: 'agency_location_id'}])
        end
      else
        json_response(errors: errors)
      end
    else
      Ctx.log_bad_access("user tried to update transfer proposal without permission")
      [404]
    end
  end

  Endpoint.get('/stream-file')
    .param(:key, String, "File key to stream") do
    if Ctx.user_logged_in?
      [
        200,
        {'Content-Type' => 'application/octet-stream'},
        ByteStorage.get.to_enum(:get_stream, params[:key])
      ]
    else
      [404]
    end
  end

  Endpoint.post('/transfer-proposals/cancel')
    .param(:id, Integer, "Transfer Proposal ID to cancel") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_transfers?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      existing_transfer = Transfers.proposal_dto_for(params[:id])
      if existing_transfer && Ctx.get.permissions.can_manage_transfers?(existing_transfer.fetch('agency_id'), existing_transfer.fetch('agency_location_id'))
        Transfers.cancel_proposal(params[:id])
        json_response(status: 'cancelled')
      else
        Ctx.log_bad_access("user tried to cancel transfer proposal in different location without permission")
        [404]
      end
    else
      Ctx.log_bad_access("user tried to cancel transfer proposal without permission")
      [404]
    end
  end

  Endpoint.post('/transfer-proposals/delete')
    .param(:id, Integer, "Transfer Proposal ID to delete") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_transfers?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      existing_transfer = Transfers.proposal_dto_for(params[:id])
      if existing_transfer && Ctx.get.permissions.can_manage_transfers?(existing_transfer.fetch('agency_id'), existing_transfer.fetch('agency_location_id'))
        Transfers.delete_proposal(params[:id])
        json_response(status: 'deleted')
      else
        Ctx.log_bad_access("user tried to delete transfer proposal in different location without permission")
        [404]
      end
    else
      Ctx.log_bad_access("user tried to delete transfer proposal without permission")
      [404]
    end
  end

  Endpoint.get('/get-messages')
    .param(:handle_id, Integer, "Handle id") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_view_conversations?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id) 
      json_response(Conversations.messages_for(params[:handle_id]))
    else
      Ctx.log_bad_access("user tried to view conversation without permission")
      json_response({})
    end
  end

  Endpoint.post('/post-message')
    .param(:message, String, "Message")
    .param(:handle_id, Integer, "Handle ID") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_view_conversations?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      Conversations.create(params[:handle_id], params[:message])
      json_response(status: 'created')
    else
      Ctx.log_bad_access("user tried to post to conversation without permission")
      [404]
    end
  end

  Endpoint.get('/transfers/:id')
    .param(:id, Integer, "ID of transfer") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_transfers?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      transfer = Transfers.transfer_dto_for(params[:id])
      if transfer && Ctx.get.permissions.can_manage_transfers?(transfer.fetch('agency_id'), transfer.fetch('agency_location_id'))
        json_response(transfer.to_hash)
      else
        Ctx.log_bad_access("user tried to get transfer without permission for location")
        [404]
      end
    else
      Ctx.log_bad_access("user tried to get transfer without permission")
      json_response({})
    end
  end

  Endpoint.post('/transfers/update')
    .param(:transfer, Transfer, "Transfer to update") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_transfers?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      existing_transfer = Transfers.transfer_dto_for(params[:transfer].fetch('id'))
      if Ctx.get.permissions.can_manage_transfers?(existing_transfer.fetch('agency_id'), existing_transfer.fetch('agency_location_id'))
        if (errors = params[:transfer].validate).empty?
          if (errors = Transfers.update_transfer_from_dto(params[:transfer])).empty?
            json_response(status: 'updated')
          else
            json_response(errors: errors)
          end
        else
          json_response(errors: errors)
        end
      else
        Ctx.log_bad_access("user tried to update transfer without permission for location")
        [404]
      end
    else
      Ctx.log_bad_access("user tried to update transfer without permission")
      [404]
    end
  end

  Endpoint.get('/import-validate')
    .param(:key, String, "The file key to validate") do

    import_file = Tempfile.new(['import_validate', '.xlsx'])
    begin
      ByteStorage.get.get_stream(params[:key]) do |chunk|
        import_file.write(chunk)
      end

      import_file.close


      errors = []

      if VALIDATION_SEMAPHORE.try_acquire(1, 60, java.util.concurrent.TimeUnit::SECONDS)
        begin
          import_validator = MapValidator.new
          import_validator.run_validations(import_file.path, import_validator.base_validations)
          import_validator.notifications.notification_list.each do |notification|
            if notification.source.to_s.empty?
              errors << "#{notification.type} - #{notification.message}"
            else
              errors << "#{notification.type} - [#{notification.source}] #{notification.message}"
            end
          end
        ensure
          VALIDATION_SEMAPHORE.release
        end
      else
        $LOG.error("Timeout waiting for available XLSX validator slot")
        errors << "SYSTEM_ERROR - Validation timeout"
      end


      json_response({'valid' => errors.empty?, 'errors' => errors})
    ensure
      import_file.unlink
    end
  end

  Endpoint.get('/file-issue-requests')
    .param(:physical_request_status, String, "Physical request status filter", :optional => true)
    .param(:digital_request_status, String, "Digital request status filter", :optional => true)
    .param(:sort, String, "Sort key", :optional => true)
    .param(:page, Integer, "Page to return") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_file_issues?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      json_response(FileIssues.requests(params[:page], AppConfig[:page_size], params[:digital_request_status], params[:physical_request_status], params[:sort]))
    else
      Ctx.log_bad_access("user tried to list file issue requests without permission")
      [404]
    end
  end

  Endpoint.post('/file-issue-requests/create')
    .param(:file_issue_request, FileIssueRequest, "File Issue Request to create") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_file_issues?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      if (errors = params[:file_issue_request].validate).empty?
        if (errors = FileIssues.create_request_from_dto(params[:file_issue_request])).empty?
          json_response(status: 'created')
        else
          json_response(errors: errors)
        end
      else
        json_response(errors: errors)
      end
    else
      Ctx.log_bad_access("user tried to create file issue request without permission")
      [404]
    end
  end

  Endpoint.get('/file-issue-requests/:id')
    .param(:id, Integer, "ID of file issue request") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_file_issues?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      file_issue_request = FileIssues.request_dto_for(params[:id])
      if file_issue_request && Ctx.get.permissions.can_manage_file_issues?(file_issue_request.fetch('agency_id'), file_issue_request.fetch('agency_location_id'))
        json_response(file_issue_request.to_hash)
      else
        Ctx.log_bad_access("user tried to get file issue request without permission for location")
        [404]
      end
    else
      Ctx.log_bad_access("user tried to get file issue request without permission")
      [404]
    end
  end

  Endpoint.post('/file-issue-requests/update')
    .param(:file_issue_request, FileIssueRequest, "File issue request to update") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_file_issues?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      if (errors = params[:file_issue_request].validate).empty?
        existing_file_issue_request = FileIssues.request_dto_for(params[:file_issue_request].fetch('id'))
        if existing_file_issue_request && Ctx.get.permissions.can_manage_transfers?(existing_file_issue_request.fetch('agency_id'), existing_file_issue_request.fetch('agency_location_id'))
          if (errors = FileIssues.update_request_from_dto(params[:file_issue_request])).empty?
            json_response(status: 'updated')
          else
            json_response(errors: errors)
          end
        else
          Ctx.log_bad_access("user tried to update file issue request without permission for location")
          json_response(errors: [{code: 'INSUFFICIENT_PRIVILEGES', field: 'agency_location_id'}])
        end
      else
        json_response(errors: errors)
      end
    else
      Ctx.log_bad_access("user tried to update file issue request without permission")
      [404]
    end
  end

  Endpoint.get('/resolve/representations')
    .param(:ref, [String], "Refs to resolve") do
    if Ctx.user_logged_in?
      json_response(Representations.for(params[:ref]))
    else
      [404]
    end
  end

  Endpoint.post('/file-issue-requests/accept')
    .param(:id, Integer, "ID of file issue request")
    .param(:lock_version, Integer, "Lock version of the file issue request")
    .param(:request_type, String, "Request type this action applies to") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_file_issues?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      existing_file_issue_request = FileIssues.request_dto_for(params[:id])
      if existing_file_issue_request && Ctx.get.permissions.can_manage_file_issues?(existing_file_issue_request.fetch('agency_id'), existing_file_issue_request.fetch('agency_location_id'))
        FileIssues.accept_request_quote(params[:id],
                                        params[:lock_version],
                                        params[:request_type])
        json_response(status: 'accepted')
      else
        Ctx.log_bad_access("user tried to accept file issue request without permission for location")
        [404]
      end
    else
      Ctx.log_bad_access("user tried to accept file issue request without permission")
      [404]
    end
  end

  Endpoint.post('/file-issue-requests/cancel')
    .param(:id, Integer, "ID of file issue request")
    .param(:lock_version, Integer, "Lock version of the file issue request")
    .param(:request_type, String, "Request type this action applies to", optional: true) do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_file_issues?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      existing_file_issue_request = FileIssues.request_dto_for(params[:id])
      if existing_file_issue_request && Ctx.get.permissions.can_manage_file_issues?(existing_file_issue_request.fetch('agency_id'), existing_file_issue_request.fetch('agency_location_id'))
        FileIssues.cancel_request(params[:id],
                                  params[:lock_version],
                                  params[:request_type])
        json_response(status: 'cancelled')
      else
        Ctx.log_bad_access("user tried to cancel file issue request without permission for location")
        [404]
      end
    else
        Ctx.log_bad_access("user tried to cancel file issue request without permission")
      [404]
    end
  end

  Endpoint.post('/file-issue-requests/delete')
    .param(:id, Integer, "File Issue Request ID to delete") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_file_issues?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      existing_file_issue_request = FileIssues.request_dto_for(params[:id])
      if existing_file_issue_request && Ctx.get.permissions.can_manage_file_issues?(existing_file_issue_request.fetch('agency_id'), existing_file_issue_request.fetch('agency_location_id'))
        FileIssues.delete_request(params[:id])
        json_response(status: 'deleted')
      else
        Ctx.log_bad_access("user tried to delete file issue request without permission for location")
        [404]
      end
    else
      Ctx.log_bad_access("user tried to delete file issue request without permission")
      [404]
    end
  end

  Endpoint.get('/file-issues')
    .param(:issue_type, String, "Issue type filter", :optional => true)
    .param(:status, String, "Status filter", :optional => true)
    .param(:sort, String, "Sort key", :optional => true)
    .param(:page, Integer, "Page to return") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_file_issues?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      json_response(FileIssues.file_issues(params[:page], AppConfig[:page_size], params[:issue_type], params[:status], params[:sort]))
    else
      Ctx.log_bad_access("user tried to list file issues without permission")
      [404]
    end
  end

  Endpoint.get('/file-issues/:id')
    .param(:id, Integer, "ID of file issue") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_file_issues?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      file_issue = FileIssues.file_issue_dto_for(params[:id])
      if file_issue && Ctx.get.permissions.can_manage_file_issues?(file_issue.fetch('agency_id'), file_issue.fetch('agency_location_id'))
        json_response(file_issue.to_hash)
      else
        Ctx.log_bad_access("user tried to get file issue without permission for location")
        [404]
      end
    else
      Ctx.log_bad_access("user tried to get file issue without permission")
      [404]
    end
  end

  Endpoint.get('/file-issue-fee-schedule') do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_file_issues?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      chargeable_services = ServiceQuotes.chargeable_services(['File Issue Physical', 'File Issue Digital'])
      json_response(chargeable_services)
    else
      Ctx.log_bad_access("user tried to get fee schedule without permission")
      [404]
    end
  end

  Endpoint.get('/file-issue-requests/:id/digital_quote')
  .param(:id, Integer, "File Issue Request ID") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_file_issues?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      file_issue_request = FileIssues.request_dto_for(params[:id])
      if file_issue_request && Ctx.get.permissions.can_manage_file_issues?(file_issue_request.fetch('agency_id'), file_issue_request.fetch('agency_location_id'))
        json_response(ServiceQuotes.get_quote(file_issue_request.fetch('aspace_digital_quote_id')))
      else
        Ctx.log_bad_access("user tried to get digital quote without permission for location")
        [404]
      end
    else
        Ctx.log_bad_access("user tried to get digital quote without permission")
      [404]
    end
  end

  Endpoint.get('/file-issue-requests/:id/physical_quote')
    .param(:id, Integer, "File Issue ID") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_file_issues?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      file_issue_request = FileIssues.request_dto_for(params[:id])
      if file_issue_request && Ctx.get.permissions.can_manage_file_issues?(file_issue_request.fetch('agency_id'), file_issue_request.fetch('agency_location_id'))
        json_response(ServiceQuotes.get_quote(file_issue_request.fetch('aspace_physical_quote_id')))
      else
        Ctx.log_bad_access("user tried to get physical quote without permission for location")
        [404]
      end
    else
      Ctx.log_bad_access("user tried to get physical quote without permission")
      [404]
    end
  end

  Endpoint.get('/notifications') do
    if Ctx.user_logged_in?
      notifications = []

      if Ctx.get.permissions.is_admin?
        notifications += Users.get_notifications
        notifications += Locations.get_notifications(false)
        notifications += Agencies.get_notifications
      else
        can_manage_file_issues = Ctx.get.permissions.can_manage_file_issues?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
        can_manage_transfers = Ctx.get.permissions.can_manage_transfers?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)

        if can_manage_file_issues
          notifications += FileIssues.get_notifications
        end

        if can_manage_transfers
          notifications += Transfers.get_notifications
        end

        if Ctx.get.permissions.can_manage_agencies?
          notifications += Agencies.get_notifications
        end

        notifications += Conversations.get_notifications(can_manage_file_issues, can_manage_transfers)

        notifications += SearchRequests.get_notifications

        if Ctx.get.permissions.can_manage_locations?(Ctx.get.current_location.agency.fetch('id'))
          notifications += Locations.get_notifications(true)
        end
      end

      # Sort descending and show events with timestamp at midnight to show at
      # top of the day
      json_response(notifications.sort {|a,b|
        time_a = Time.at(a.timestamp / 1000)
        time_b = Time.at(b.timestamp / 1000)

        if time_a.hour == 0 && time_a.min == 0 && time_a.sec == 0
          time_a = (time_a.to_date + 1).to_time
        end

        if time_b.hour == 0 && time_b.min == 0 && time_b.sec == 0
          time_b = (time_b.to_date + 1).to_time
        end

        time_b <=> time_a
      })
    else
      [404]
    end
  end

  Endpoint.get('/stream-file-issue', needs_session: false)
    .param(:token, String, "File issue token") do
    result = FileIssues.get_file_issue(params[:token])

    if result.fetch(:status) == :found
      [200, {"Content-Type" => result.fetch(:mime_type)}, result.fetch(:stream)]
    elsif result.fetch(:status) == :missing
      $LOG.warn("File issue token was missing: #{params[:token]}")
      [404]
    elsif result.fetch(:status) == :expired
      Ctx.log_bad_access("Attempt to access expired token: #{params[:token]}")
      [410]
    elsif result.fetch(:status) == :not_dispatched
      Ctx.log_bad_access("Attempt to access file issue before it was dispatched: #{params[:token]}")
      [425]
    else
      raise "Unexpected status"
    end
  end

  Endpoint.get('/search-requests')
    .param(:sort, String, "Sort key", :optional => true)
    .param(:status, String, "Status filter", :optional => true)
    .param(:page, Integer, "Page to return") do
    if Ctx.user_logged_in? && Ctx.get.permissions.has_role_for_location?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      json_response(SearchRequests.search_requests(params[:page], AppConfig[:page_size], params[:status], params[:sort]))
    else
      Ctx.log_bad_access("Attempt to search requests without permission")
      [404]
    end
  end

  Endpoint.post('/search-requests/create')
    .param(:search_request, SearchRequest, "Search Request to create") do
    if Ctx.user_logged_in? && Ctx.get.permissions.has_role_for_location?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      if (errors = params[:search_request].validate).empty?
        if (errors = SearchRequests.create_from_dto(params[:search_request])).empty?
          json_response(status: 'created')
        else
          json_response(errors: errors)
        end
      else
        json_response(errors: errors)
      end
    else
      Ctx.log_bad_access("Attempt to create search request without permission")
      [404]
    end
  end

  Endpoint.get('/search-requests/:id')
    .param(:id, Integer, "ID of search request") do
    if Ctx.user_logged_in? && Ctx.get.permissions.has_role_for_location?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      search_request = SearchRequests.dto_for(params[:id])
      if search_request && Ctx.get.permissions.has_role_for_location?(search_request.fetch('agency_id'), search_request.fetch('agency_location_id'))
        json_response(search_request.to_hash)
      else
        Ctx.log_bad_access("Attempt to get search request without permission for location")
        [404]
      end
    else
        Ctx.log_bad_access("Attempt to get search request without permission")
      [404]
    end
  end

  Endpoint.post('/search-requests/update')
    .param(:search_request, SearchRequest, "Search Request to create") do
    if Ctx.user_logged_in? && Ctx.get.permissions.has_role_for_location?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      if (errors = params[:search_request].validate).empty?
        existing_search_request = SearchRequests.dto_for(params[:search_request].fetch('id'))
        if existing_search_request && Ctx.get.permissions.has_role_for_location?(existing_search_request.fetch('agency_id'), existing_search_request.fetch('agency_location_id'))
          if (errors = SearchRequests.update_from_dto(params[:search_request])).empty?
            json_response(status: 'updated')
          else
            json_response(errors: errors)
          end
        else
          Ctx.log_bad_access("Attempt to update search request without permission for location")
          json_response(errors: [{code: 'INSUFFICIENT_PRIVILEGES', field: 'agency_location_id'}])
        end
      else
        json_response(errors: errors)
      end
    else
      Ctx.log_bad_access("Attempt to update search request without permission")
      [404]
    end
  end

  Endpoint.post('/search-requests/cancel')
    .param(:id, Integer, "ID of search request")
    .param(:lock_version, Integer, "Lock version of search request") do
    if Ctx.user_logged_in? && Ctx.get.permissions.has_role_for_location?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      existing_search_request = SearchRequests.dto_for(params[:id])
      if existing_search_request && Ctx.get.permissions.has_role_for_location?(existing_search_request.fetch('agency_id'), existing_search_request.fetch('agency_location_id'))
        if (errors = SearchRequests.cancel(params[:id], params[:lock_version])).empty?
          json_response(status: 'updated')
        else
          json_response(errors: errors)
        end
      else
        Ctx.log_bad_access("Attempt to cancel search request without permission for location")
        json_response(errors: [{code: 'INSUFFICIENT_PRIVILEGES', field: 'agency_location_id'}])
      end
    else
      Ctx.log_bad_access("Attempt to cancel search request without permission")
      [404]
    end
  end


  Endpoint.get('/search-requests/:id/quote')
    .param(:id, Integer, "Search Request ID")do
    if Ctx.user_logged_in? && Ctx.get.permissions.has_role_for_location?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      existing_search_request = SearchRequests.dto_for(params[:id])
      if existing_search_request && Ctx.get.permissions.has_role_for_location?(existing_search_request.fetch('agency_id'), existing_search_request.fetch('agency_location_id'))
        if existing_search_request.fetch('aspace_quote_id', false)
          json_response(ServiceQuotes.get_quote(existing_search_request.fetch('aspace_quote_id')))
        else
          [404]
        end
      else
        Ctx.log_bad_access("Attempt to get search request quote without permission for location")
        [404]
      end
    else
      Ctx.log_bad_access("Attempt to get search request quote without permission")
      [404]
    end
  end

  Endpoint.get('/search-request-fee-schedule') do
    if Ctx.user_logged_in? && Ctx.get.permissions.has_role_for_location?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      chargeable_services = ServiceQuotes.chargeable_services(['Search Request'])
      json_response(chargeable_services)
    else
      Ctx.log_bad_access("Attempt to get search request fee schedule without permission")
      [404]
    end
  end

  Endpoint.post('/users/assign-to-location')
    .param(:username, String, "The username to assign")
    .param(:location_id, Integer, "The location to assign them to")
    .param(:role, String, "The role to grant") do
    if (user_id = Users.id_for_username(params[:username])).nil?
      json_response(["no such user"])
    else
      json_response(Permissions.assign_to_location(user_id, params[:location_id], params[:role]))
    end
  end

  Endpoint.get('/system-administrators') do
    if Ctx.get.permissions.is_admin?
      json_response(Users.get_system_admins)
    else
      Ctx.log_bad_access("Attempt to access system-administrators list")
      [403]
    end
  end

end
