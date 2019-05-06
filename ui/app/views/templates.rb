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

Templates.define(:hello, [:name, :agency?, :location?], "views/hello.erb.html")
Templates.define(:example_partial, [], "views/_partial.erb.html")

Templates.define(:layout, [:title, :template, :template_args, :message?, [:context]], "views/layout.erb.html")
Templates.define(:layout_blank, [:title, :template, :template_args, :message?], "views/layout_blank.erb.html")
Templates.define(:login, [:username?, :message?], "views/login.erb.html")
Templates.define(:users, [:paged_users], "views/users.erb.html")
Templates.define(:user_new, [:user, :errors?], "views/user_form.erb.html")
Templates.define(:user_edit, [:user, :errors?], "views/user_form.erb.html")
Templates.define(:locations, [:paged_results], "views/locations.erb.html")
Templates.define(:location_new, [:location, :errors?], "views/location_form.erb.html")
Templates.define(:location_edit, [:location, :errors?], "views/location_form.erb.html")
Templates.define(:flash_message, [:message], "views/_message.erb.html")
Templates.define(:header, [:title, [:context]], "views/header.erb.html")

Templates.define(:transfer_proposals, [:paged_results], "views/transfer_proposals.erb.html")
Templates.define(:transfers, [:paged_results], "views/transfers.erb.html")
Templates.define(:transfer_proposal_new, [:transfer, :errors?, :is_readonly], "views/transfer_proposal_form.erb.html")
Templates.define(:transfer_proposal_view, [:transfer, :errors?, :is_readonly], "views/transfer_proposal_form.erb.html")
Templates.define(:transfer_view, [:transfer, :errors?, :is_readonly], "views/transfer_form.erb.html")
