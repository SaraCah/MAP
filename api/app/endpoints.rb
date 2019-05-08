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
      if Ctx.get.permissions.is_admin?
        json_response(Users.all(params[:page], 10))
      elsif Ctx.get.permissions.is_senior_agency_admin?(Ctx.get.current_location.agency_id)
        json_response(Users.for_agency(params[:page], 10, Ctx.get.current_location.agency_id))
      elsif Ctx.get.permissions.is_agency_admin?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
        json_response(Users.for_agency_location(params[:page], 10, Ctx.get.current_location.agency_id, Ctx.get.current_location.id))
      else
        [404]
      end
    else
      [404]
    end
  end

  Endpoint.post('/users/create')
    .param(:user, UserDTO, "User") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_create_users?
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
      [404]
    end
  end

  Endpoint.post('/users/update')
    .param(:user, UserDTO, "User") do
    if Ctx.user_logged_in? #FIXME check if can update the user
      if (errors = params[:user].validate).empty?
        if !(errors = Users.validate_roles(params[:user])).empty?
          json_response(errors: errors)
        elsif (errors = Users.update_from_dto(params[:user])).empty?
          json_response(status: 'updated')
        else
          json_response(errors: errors)
        end
      else
        json_response(errors: errors) unless errors.empty?
      end
    else
      [404]
    end
  end

  Endpoint.get('/search/agencies')
    .param(:q, String, "Search string") do
    permissions = Users.permissions_for_user(Ctx.username)
    json_response(Search.agency_typeahead(params[:q], permissions))
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
      if Ctx.get.permissions.is_admin?
        json_response(Locations.all(params[:page], 10))
      elsif Ctx.get.permissions.is_senior_agency_admin?(Ctx.get.current_location.agency_id)
        json_response(Locations.for_agency(params[:page], 10, Ctx.get.current_location.agency_id))
      elsif Ctx.get.permissions.is_agency_admin?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
        json_response(Locations.for_agency_location(params[:page], 10, Ctx.get.current_location.agency_id, Ctx.get.current_location.id))
      else
        [404]
      end
    else
      [404]
    end
  end

  Endpoint.get('/locations_for_agency')
    .param(:agency_ref, String, "Agency Ref") do
    if Ctx.user_logged_in?
      (_, aspace_agency_id) =  params[:agency_ref].split(':')
      if Ctx.get.permissions.is_admin? || Ctx.get.permissions.agency_roles.any?{|role| role.aspace_agency_id == Integer(aspace_agency_id)}
        json_response(Locations.locations_for_agency(aspace_agency_id))
      else
        [404]
      end
    else
      [404]
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
          json_response(errors: [{code: 'INSUFFICIENT_PRIVILEGES', field: 'agency_ref'}])
        end
      else
        json_response(errors: errors)
      end
    else
      [404]
    end
  end


  Endpoint.get('/locations/:id')
    .param(:id, Integer, "ID of agency location") do
    if Ctx.user_logged_in?
      location = Locations.dto_for(params[:id])
      if Ctx.get.permissions.can_manage_locations?(location.fetch('agency_ref'))
        json_response(location.to_hash)
      else
        [404]
      end
    else
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
        json_response(errors: [{code: 'INSUFFICIENT_PRIVILEGES', field: 'agency_ref'}])
      end
    else
      json_response(errors: errors)
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
      json_response(Agencies.get_summary(Ctx.get.current_location.agency_id))
    else
      json_response({})
    end
  end

  Endpoint.post('/set-location')
    .param(:agency_id, Integer, "Agency Id")
    .param(:location_id, Integer, "Location Id") do

    if Ctx.get.permissions.has_role_for_location?(params[:agency_id], params[:location_id])
      Ctx.get.set_location(params[:agency_id], params[:location_id])
      json_response(status: 'ok')
    else
      [403]
    end
  end

  Endpoint.get('/user-for-edit')
    .param(:username, String, "Username to authenticate") do
    if Ctx.user_logged_in?
      user = Users.dto_for(params[:username])
      if Ctx.username == params[:username] || Ctx.get.permissions.can_edit_user?(user)
        json_response(user.to_hash)
      else
        [404]
      end
    else
      [404]
    end
  end

  Endpoint.get('/transfer-proposals')
    .param(:page, Integer, "Page to return") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_transfers?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      json_response(Transfers.proposals(params[:page], 10))
    else
      [404]
    end
  end

  Endpoint.get('/transfers')
    .param(:page, Integer, "Page to return") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_transfers?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      json_response(Transfers.transfers(params[:page], 10))
    else
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
      [404]
    end
  end

  Endpoint.post('/store-files')
    .param(:file, [UploadFile], "Files to store") do
    if Ctx.user_logged_in?
      json_response(params[:file].map {|file| Files.store(file.tmp_file)})
    else
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
          json_response(errors: [{code: 'INSUFFICIENT_PRIVILEGES', field: 'agency_location_id'}])
        end
      else
        json_response(errors: errors)
      end
    else
      [404]
    end
  end

  Endpoint.get('/stream-file')
    .param(:key, String, "File key to stream") do
    if Ctx.user_logged_in?
      # FIXME stream it
      [
        200,
        {'Content-Type' => 'application/octet-stream'},
        StringIO.new(Files.read(params[:key]))
      ]
    else
      [404]
    end
  end

  Endpoint.post('/transfer-proposals/cancel')
    .param(:id, Integer, "Transfer Propposal ID to cancel") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_transfers?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      existing_transfer = Transfers.proposal_dto_for(params[:id])
      if existing_transfer && Ctx.get.permissions.can_manage_transfers?(existing_transfer.fetch('agency_id'), existing_transfer.fetch('agency_location_id'))
        Transfers.cancel_proposal(params[:id])
        json_response(status: 'cancelled')
      else
        [404]
      end
    else
      [404]
    end
  end

  Endpoint.get('/get-messages')
    .param(:record_type, String, "Record type")
    .param(:id, String, "Record id") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_view_conversations?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id) 
      json_response(Conversations.messages_for(params[:record_type], params[:id]))
    else
      json_response({})
    end
  end

  Endpoint.post('/post-message')
    .param(:message, String, "Message")
    .param(:record_type, String, "Record Type")
    .param(:id, Integer, "Record ID") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_view_conversations?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      Conversations.create(params[:record_type], params[:id], params[:message])
      json_response(status: 'created')
    else
      [404]
    end
  end

  Endpoint.get('/transfers/:id')
    .param(:id, Integer, "ID of transfer") do
    if Ctx.user_logged_in? && Ctx.get.permissions.can_manage_transfers?(Ctx.get.current_location.agency_id, Ctx.get.current_location.id)
      transfer = Transfers.transfer_dto_for(params[:id])
      if transfer && Ctx.get.permissions.can_manage_transfers?(transfer.fetch('agency_id'), transfer.fetch('agency_location_id'))
        json_response(transfer.to_hash)
      end
    else
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
        [404]
      end
    else
      [404]
    end
  end

end
