# You define templates with a name, a list of parameters they take, and an ERB
# file.
#
# If param ends with '?' it's allowed to be nil.
#
# If param is wrapped in an array, that's an array of something.  If you don't
# specify it, you get [].
#
# Partials would work the same way--just <%== Templates.emit(:partial_name) %>
#

Templates.define(:hello, [:name], "views/hello.erb.html")
Templates.define(:example_partial, [], "views/_partial.erb.html")

Templates.define(:layout, [:title, :template, :template_args, :message?, [:context]], "views/layout.erb.html")
Templates.define(:layout_blank, [:title, :template, :template_args, :message?], "views/layout_blank.erb.html")

Templates.define(:qgov_header, [], "views/qgov_header.erb.html")
Templates.define(:qgov_footer, [], "views/qgov_footer.erb.html")

Templates.define(:login, [:username?, :message?, :delay_seconds?], "views/login.erb.html")
Templates.define(:mfa, [:message?], "views/mfa.erb.html")

Templates.define(:records, [:agency?, :location?], "views/records.erb.html")

Templates.define(:user_edit, [:user, :errors?], "views/user_form.erb.html")
Templates.define(:manage_mfa, [:secret, :regenerate, :qr_code, :current_token], "views/manage_mfa.erb.html")
Templates.define(:manage_mfa_no_key, [], "views/manage_mfa_no_key.erb.html")
Templates.define(:location_edit, [:location, :errors?], "views/location_form.erb.html")
Templates.define(:location_add_user, [:location, :user, :mode, :role?, :position?, :errors?], "views/location_add_user_form.erb.html")
Templates.define(:flash_message, [:message], "views/_message.erb.html")
Templates.define(:header, [:title, [:context]], "views/header.erb.html")

Templates.define(:transfer_proposals, [:paged_results, :sort?, :status?, :params], "views/transfer_proposals.erb.html")
Templates.define(:transfers, [:paged_results, :sort?, :status?, :params], "views/transfers.erb.html")
Templates.define(:transfer_proposal_view, [:transfer, :errors?, :is_readonly], "views/transfer_proposal_form.erb.html")
Templates.define(:transfer_view, [:transfer, :errors?, :is_readonly], "views/transfer_form.erb.html")

Templates.define(:file_issue_requests, [:paged_results, :digital_request_status?, :physical_request_status?, :sort?, :params], "views/file_issue_requests.erb.html")
Templates.define(:file_issue_request_view, [:request, :resolved_representations?, :errors?, :is_readonly?, :digital_request_quote?, :physical_request_quote?], "views/file_issue_request_form.erb.html")
Templates.define(:file_issues, [:paged_results, :sort?, :issue_type?, :status?, :params], "views/file_issues.erb.html")
Templates.define(:file_issue_view, [:file_issue, :resolved_representations?, :errors?, :is_readonly?], "views/file_issue_form.erb.html")

Templates.define(:fee_schedule, [:chargeable_services], "views/fee_schedule.erb.html")

Templates.define(:file_issue_download_expired, [], "views/file_issue_download_expired.erb.html")
Templates.define(:file_issue_download_missing, [], "views/file_issue_download_missing.erb.html")
Templates.define(:file_issue_not_dispatched, [], "views/file_issue_not_dispatched.erb.html")

Templates.define(:search_requests, [:paged_results, :sort?, :status?, :params], "views/search_requests.erb.html")
Templates.define(:search_request_view, [:request, :errors?, :is_readonly?, :quote?], "views/search_request_form.erb.html")

Templates.define(:agencies, [:paged_agencies, :q?, :params], "views/agencies.erb.html")
Templates.define(:manage_agency, [:agency_ref], "views/manage_agency.erb.html")
Templates.define(:manage_system, [], "views/manage_system.erb.html")

Templates.define(:location_edit_user_permissions,
                 [:user_id, :location_id, :is_top_level, :username, :role, :removable_from_location, :position?, [:existing_permissions], [:available_permissions], :errors?],
                 "views/location_edit_user_permissions.erb.html")

Templates.define(:location_delete_confirmation,
                 [:location, :users_who_would_become_unlinked],
                 "views/location_delete_confirmation.erb.html")

Templates.define(:reading_room_requests,
                 [:paged_results, :resolved_representations, :sort?, :status?, :params],
                 "views/reading_room_requests.erb.html")

Templates.define(:reading_room_request_view,
                 [:request, :requested_items, :resolved_representations?, :errors?, :is_readonly?],
                 "views/reading_room_request_form.erb.html")