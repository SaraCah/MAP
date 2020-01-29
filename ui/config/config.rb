#AppConfig[:session_secret] = 'randomly_generated_token'
AppConfig[:map_api_url] = 'http://localhost:5678'
AppConfig[:page_size] = 10

AppConfig[:file_issue_request_types] = ['Right to Information', 'National Redress Scheme']
AppConfig[:search_request_purposes] = ['RTI', 'Redress']

AppConfig[:file_upload_allowed_extensions] = [
  'bmp',
  'csv',
  'doc',
  'docx',
  'gif',
  'jpg',
  'jpeg',
  'pdf',
  'png',
  'ppt',
  'pptx',
  'tif',
  'tiff',
  'tsv',
  'xls',
  'xlsx',
]

AppConfig[:file_upload_allowed_mime_types] = [
  'image/bmp',
  'text/csv',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'image/gif',
  'image/jpeg',
  'application/pdf',
  'image/png',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'image/tiff',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'text/tab-separated-values',
]

AppConfig[:public_url] = 'http://localhost:3009'

begin
  load File.join(File.dirname(__FILE__), "config.local.rb")
rescue LoadError
end
