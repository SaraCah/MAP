require 'net/http'
require 'net/http/post/multipart'

class MAPAPIClient

  # Documented as thread safe, so we'll share between all threads to reduce the
  # need to connect.
  @http_persistent = Net::HTTP::Persistent.new(name: "map_api_client")

  def self.http_persistent
    @http_persistent
  end

  def http_client
    self.class.http_persistent
  end

  def initialize(session)
    @session = session
  end

  Authentication = Struct.new(:successful, :session_id, :permissions) do
    def successful?
      self.successful
    end
  end

  AgencyRole = Struct.new(:agency_id, :agency_label, :aspace_agency_id, :agency_location_id, :role, :permissions) do
    def self.from_json(json)
      new(json.fetch('agency_id'),
          json.fetch('agency_label'),
          json.fetch('aspace_agency_id'),
          json.fetch('agency_location_id'),
          json.fetch('role'),
          json.fetch('permissions'))
    end

    def is_senior_agency_admin?
      self.role == 'SENIOR_AGENCY_ADMIN'
    end

    def is_agency_admin?
      is_senior_agency_admin? || self.role == 'AGENCY_ADMIN'
    end

    def agency_ref
      "agent_corporate_entity:#{self.aspace_agency_id}"
    end

    def allow_transfers?
      self.permissions.include?('allow_transfers')
    end

    def allow_file_issue?
      self.permissions.include?('allow_file_issue')
    end
  end

  Permissions = Struct.new(:is_admin, :agency_roles) do
    def self.from_json(json)
      new(json.fetch('is_admin'),
          json.fetch('agency_roles', []).map {|agency_role_json| AgencyRole.from_json(agency_role_json)})
    end

    def allow_manage_users?
      self.is_admin || is_agency_admin?
    end

    def is_admin?
      self.is_admin
    end

    def allow_manage_locations?
      self.is_admin || is_senior_agency_admin?
    end

    def current_agency_roles
      if Ctx.get.current_location
        self.agency_roles.select{|role| role.agency_id == Ctx.get.current_location.agency_id}
      else
        []
      end
    end

    def current_location_roles
      current_agency_roles.select{|role| role.agency_location_id == Ctx.get.current_location.id}
    end

    def allow_manage_transfers?
      is_senior_agency_admin? || current_location_roles.any?{|role| role.allow_transfers?}
    end

    def allow_manage_file_issues?
      is_senior_agency_admin? || current_location_roles.any?{|role| role.allow_file_issue?}
    end

    def is_senior_agency_admin?
      current_agency_roles.any?{|role| role.is_senior_agency_admin?}
    end

    def is_agency_admin?
      is_senior_agency_admin? || current_location_roles.any?{|role| role.is_agency_admin?}
    end
  end

  def permission_options
    [:allow_transfers, :allow_file_issue, :allow_set_raps, :allow_change_raps, :allow_restricted_access]
  end

  def authenticate(username, password)
    response = post('/authenticate', username: username, password: password)

    if response['authenticated']
      Authentication.new(true, response['session'], response['permissions'])
    else
      Authentication.new(false)
    end
  end

  User = Struct.new(:username, :name, :is_admin, :is_inactive, :create_time, :agency_roles) do
    def self.from_json(json)
      User.new(json.fetch('username'),
               json.fetch('name'),
               json.fetch('is_admin'),
               json.fetch('is_inactive'),
               json.fetch('create_time'),
               json.fetch('agency_roles').map do |agency, role, location_label|
                 [Agency.from_json(agency), role, location_label]
               end)
    end

    def can_edit?
      return true if Ctx.get.permissions.is_admin?
      return true if Ctx.get.permissions.is_senior_agency_admin?

      agency_roles.any? {|_, role, _|
        role != 'SENIOR_AGENCY_ADMIN'
      }
    end
  end

  Agency = Struct.new(:id, :label, :series_count, :controlled_records) do
    def initialize(*)
      super
      self.series_count ||= 0
      self.controlled_records ||= []
    end

    def self.from_json(json)
      Agency.new(json.fetch('id'),
                 json.fetch('label'),
                 json.fetch('series_count', 0),
                 json.fetch('controlled_records'))
    end


    def to_json(*args)
      to_h.to_json
    end
  end

  PagedResults = Struct.new(:results, :current_page, :max_page) do
    def self.from_json(json, type_class)
      PagedResults.new(json.fetch('results', []).map{|user_json| type_class.included_modules.include?(DTO) ? type_class.from_hash(user_json) : type_class.from_json(user_json)},
                     json.fetch('current_page'),
                     json.fetch('max_page'))
    end
  end


  def users(page = 0)
    PagedResults.from_json(get('/users', page: page), User)
  end

  def groups
    get('/groups')
  end

  def create_user(user)
    response = post('/users/create', user: user.to_json)
    response['errors'] || []
  end

  def update_user(user)
    response = post('/users/update', user: user.to_json)
    response['errors'] || []
  end

  def user_for_edit(username)
    json = get('/user-for-edit', {username: username})

    return nil if json.nil?

    UserDTO.from_hash(json)
  end

  def create_location(location)
    response = post('/locations/create', location: location.to_json)
    response['errors'] || []
  end

  def location_for_edit(agency_location_id)
    json = get("/locations/#{agency_location_id}")

    return nil if json.nil?

    AgencyLocationDTO.from_hash(json)
  end

  def update_location(location)
    response = post('/locations/update', location: location.to_json)
    response['errors'] || []
  end

  def agency_typeahead(q)
    get('/search/agencies', q: q)
  end


  def representation_typeahead(q)
    get('/search/representations', q: q)
  end

  def find_record(record_ref)
    get('/search/get_record', record_ref: record_ref)
  end

  def get_current_agency
    return nil if Ctx.get.permissions.is_admin?
    Agency.from_json(get('/my-agency', {}))
  end

  def get_controlled_records(q, filters, start_date, end_date, page, page_size)
    return [] if Ctx.get.permissions.is_admin?

    params = {page: page, page_size: page_size}

    params[:q] = q unless q.to_s.empty?
    params[:filters] = JSON.dump(filters)
    params[:start_date] = start_date unless start_date.to_s.empty?
    params[:end_date] = end_date unless end_date.to_s.empty?

    get('/controlled-records', params)
  end

  AgencyLocation = Struct.new(:id, :name, :agency_id, :create_time, :agency) do
    def self.from_json(json)
      AgencyLocation.new(json.fetch('id'),
                         json.fetch('name'),
                         json.fetch('agency_id'),
                         json.fetch('create_time'),
                         Agency.from_json(json.fetch('agency')))
    end

    def to_search_result
      {
        'id' => id,
        'label' => name
      }
    end

    def to_json(*args)
      to_h.to_json
    end
  end

  def locations(page = 0)
    PagedResults.from_json(get('/locations', page: page), AgencyLocation)
  end

  def locations_for_agency(agency_ref)
    get('/locations_for_agency', {
      'agency_ref' => agency_ref,
    }).map do |json|
      AgencyLocation.from_json(json)
    end
  end

  def permissions_for_current_user
    Permissions.from_json(get('/my-permissions', {}))
  end

  def location_for_current_user
    json = get('/my-location', {})

    return nil if json.nil?

    AgencyLocation.from_json(json)
  end

  def locations_for_current_user
    get('/my-locations', {})
  end

  def set_location(agency_id, location_id)
    post('/set-location', {
      agency_id: agency_id,
      location_id: location_id,
    })
  end

  def transfer_proposals(page = 0)
    PagedResults.from_json(get('/transfer-proposals', page: page), TransferProposal)
  end


  def transfers(page = 0)
    PagedResults.from_json(get('/transfers', page: page), Transfer)
  end

  def create_transfer_proposal(transfer)
    response = post('/transfer-proposals/create', transfer: transfer.to_json)
    response['errors'] || []
  end

  def store_files(files)
    post('/store-files',
         { "file[]" => files.map(&:to_io) },
         :multipart_form_data)
  end

  def stream_file(key)
    get('/stream-file', { "key" => key }, true)
  end

  def get_transfer_proposal(transfer_proposal_id)
    json = get("/transfer-proposals/#{transfer_proposal_id}")

    return nil if json.nil?

    TransferProposal.from_hash(json)
  end

  def update_transfer_proposal(transfer)
    response = post('/transfer-proposals/update', transfer: transfer.to_json)
    response['errors'] || []
  end

  def cancel_transfer_proposal(transfer_proposal_id)
    post('/transfer-proposals/cancel', id: transfer_proposal_id)
  end

  ConversationMessage = Struct.new(:message, :author, :timestamp) do
    def self.from_json(json)
      new(json.fetch('message'),
          json.fetch('author'),
          json.fetch('timestamp'))
    end

    def to_json(*args)
      to_h.to_json
    end
  end

  def get_messages(handle_id)
    get('/get-messages', {
      'handle_id' => handle_id,
    }).map do |json|
      ConversationMessage.from_json(json)
    end
  end

  def post_message(handle_id, message)
    post('/post-message', handle_id: handle_id,
                          message: message)
  end

  def get_transfer(transfer_id)
    json = get("/transfers/#{transfer_id}")

    return nil if json.nil?

    Transfer.from_hash(json)
  end

  def update_transfer(transfer)
    response = post('/transfers/update', transfer: transfer.to_json)
    response['errors'] || []
  end

  def import_validate(key)
    get("/import-validate", :key => key)
  end


  def file_issue_requests(page = 0)
    PagedResults.from_json(get('/file-issue-requests', page: page), FileIssueRequest)
  end

  def create_file_issue_request(file_issue_request)
    response = post('/file-issue-requests/create', file_issue_request: file_issue_request.to_json)
    response['errors'] || []
  end

  def get_file_issue_request(file_issue_request_id)
    json = get("/file-issue-requests/#{file_issue_request_id}")

    return nil if json.nil?

    FileIssueRequest.from_hash(json)
  end

  def update_file_issue_request(file_issue_request)
    response = post('/file-issue-requests/update', file_issue_request: file_issue_request.to_json)
    response['errors'] || []
  end

  def resolve_representations(refs)
    return [] if refs.empty?

    get("/resolve/representations", { 'ref[]' => refs })
  end

  def accept_file_issue_request(file_issue_request_id, lock_version, request_type)
    post('/file-issue-requests/accept', id: file_issue_request_id,
                                        lock_version: lock_version,
                                        request_type: request_type)
  end

  def cancel_file_issue_request(file_issue_request_id, lock_version, request_type)
    data = {
      id: file_issue_request_id,
      lock_version: lock_version
    }

    data[:request_type] = request_type if request_type

    post('/file-issue-requests/cancel', data)
  end

  def file_issues(page = 0)
    PagedResults.from_json(get('/file-issues', page: page), FileIssue)
  end

  def get_file_issue(file_issue_id)
    json = get("/file-issues/#{file_issue_id}")

    return nil if json.nil?

    FileIssue.from_hash(json)
  end

  def get_file_issue_fee_schedule
    get("/file-issue-fee-schedule")
  end

  def get_file_issue_quote(quote_id)
    get("/file-issue-quotes/#{quote_id}")
  end

  def file_issue_notifications
    get("/file_issue_notifications")
  end

  def stream_file_issue(token, suggested_filename)
    stream_get('/stream-file-issue', suggested_filename, { "token" => token })
  end

  class ClientError < StandardError
    def initialize(json)
      @json = json
      super
    end
  end

  class FileIssueExpired < StandardError; end
  class FileIssueNotFound < StandardError; end
  class FileIssueNotDispatched < StandardError; end

  private

  def post(url, params = {}, encoding = :x_www_form_urlencoded)
    uri = build_url(url)

    request = if encoding == :x_www_form_urlencoded
                req = Net::HTTP::Post.new(uri)
                req.form_data = params
                req
              elsif encoding == :multipart_form_data
                Net::HTTP::Post::Multipart.new(uri, params)
              else
                raise "Unknown form encoding: #{encoding.inspect}"
              end

    request['X-MAP-SESSION'] = @session[:api_session_id] if @session[:api_session_id]

    response = http_client.request(uri, request)

    check_errors!(response)

    JSON.parse(response.body)
  end

  def get(url, params = {}, raw = false)
    uri = build_url(url, params)

    request = Net::HTTP::Get.new(uri)
    request['X-MAP-SESSION'] = @session[:api_session_id] if @session[:api_session_id]

    response = http_client.request(uri, request)

    check_errors!(response)

    if raw
      response.body
    else
      JSON.parse(response.body)
    end
  end


  class StreamHTTPRequest
    def initialize(client, request, uri)
      @client = client
      @request = request
      @uri = uri

      @queue = java.util.concurrent.LinkedBlockingQueue.new(1)
      @response_code_future = java.util.concurrent.CompletableFuture.new
      @response_headers_future = java.util.concurrent.CompletableFuture.new

      start_thread!
    end

    def response_code
      @response_code_future.get
    end

    def headers
      @response_headers_future.get
    end

    def start_thread!
      Thread.new do
        begin
          @client.request(@uri, @request) do |response|
            @response_code_future.complete(response.code)
            @response_headers_future.complete(response)

            if response.code == '200'
              response.read_body do |chunk|
                @queue.offer(chunk.bytes, 60, java.util.concurrent.TimeUnit::SECONDS)
              end

              @queue.offer(:done, 60, java.util.concurrent.TimeUnit::SECONDS)
            end
          end
        rescue => e
          $LOG.error("Failure in StreamHTTPRequest: #{e}")
          @response_code_future.cancel
          @response_headers_future.cancel
        end
      end
    end

    def each
      loop do
        elt = @queue.poll(60, java.util.concurrent.TimeUnit::SECONDS)
        break if elt == :done

        yield elt.pack('c*')
      end
    end
  end


  def stream_get(url, suggested_filename = nil, params = {})
    uri = build_url(url, params)

    if !suggested_filename
      suggested_filename = SecureRandom.hex
    end

    request = Net::HTTP::Get.new(uri)
    request['X-MAP-SESSION'] = @session[:api_session_id] if @session[:api_session_id]

    stream = StreamHTTPRequest.new(http_client, request, uri)

    if stream.response_code == '404'
        raise FileIssueNotFound.new
    elsif stream.response_code == '410'
      raise FileIssueExpired.new
    elsif stream.response_code == '425'
      raise FileIssueNotDispatched.new
    elsif stream.response_code == '200'
      [
        200,
        {
          "Content-Type" => stream.headers['Content-Type'],
          "Content-Disposition" => "attachment; filename=\"#{suggested_filename}\"",
        },
        stream
      ]
    else
      raise ClientError.new({:stream_error => stream.response_code})
    end
  end

  class SessionGoneError < StandardError
  end

  def check_errors!(response)
    if !response.code.start_with?('2')
      error = JSON.parse(response.body)

      if error.fetch('SERVER_ERROR', {})['type'] == 'Sessions::SessionNotFoundError'
        # Our backend session is gone.  Clear the frontend one too.
        raise SessionGoneError.new
      end

      raise ClientError.new(error)
    end
  end

  def build_url(url, params = nil)
    uri = URI.join(AppConfig[:map_api_url], url)
    if params
      uri.query = URI.encode_www_form(params)
    end
    uri
  end
end
