Pod::Spec.new do |s|
  s.name     = 'MCSwipeTableViewCell@4thOffice'
  s.version  = '2.1.0'
  s.author   = { 'Ali Karagoz' => 'mail@alikaragoz.net' }
  s.homepage = 'https://github.com/alikaragoz/MCSwipeTableViewCell'
  s.summary  = 'Mailbox app style UITableViewCell.'
  s.license  = 'MIT'
  s.source   = { :git => 'https://github.com/4thOffice/MCSwipeTableViewCell.git', :tag => s.version.to_s }
  s.source_files = 'MCSwipeTableViewCell'
  s.platforms = { :ios => "7.0" }
  s.requires_arc = true
end
