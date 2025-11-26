require 'sinatra'
require 'digest/sha2'
require 'active_record'

set :environment, :production
# enable :sessions

set :sessions,
    expire_after: 7200,
    secret: ENV['SESSION_SECRET']

ActiveRecord::Base.configurations = YAML.load_file('database.yml')
ActiveRecord::Base.establish_connection :development

# Represents a user account in the system.
class Account < ActiveRecord::Base
  self.table_name = 'account'
end

# Represents a file entry in the system, storing metadata about uploaded files.
class FileEntry < ActiveRecord::Base
  self.table_name = 'files'
end

get '/' do
  redirect '/login'
end

get '/login' do
  erb :login
end

post '/auth' do
  user = params[:uname]
  pass = params[:pass]

  r = check_login(user, pass)

  if r == 1
    session[:username] = user
    redirect '/index'
  end

  redirect '/loginfailure'
end

def check_login(trial_username, trial_password)
  account = Account.find_by(id: trial_username)

  return 2 if account.nil?

  db_salt = account.salt
  db_hashed = account.hashed
  trial_hashed = Digest::SHA256.hexdigest(trial_password + db_salt)

  trial_hashed == db_hashed ? 1 : 0
rescue StandardError
  2
end

get '/logout' do
  session.clear
  erb :logout
end

get '/loginfailure' do
  session.clear
  erb :loginfailure
end

get '/index' do
  @u = session[:username]

  redirect '/badrequest' if @u.nil?

  @images_path = []

  FileEntry.all.each do |entry|
    filepath = "./public/files/#{entry.filename}"

    next unless File.exist?(filepath)

    @images_path << {
      name: entry.filename,
      size: entry.size,
      mtime: entry.upload_date
    }
  end

  @error = session.delete(:error)
  erb :index
end

post '/upload' do
  @u = session[:username]

  redirect '/badrequest' if @u.nil?

  s = params[:file]
  if !s.nil?
    filename = params[:file][:filename]
    save_path = "./public/files/#{filename}"

    File.open(save_path, 'wb') do |f|
      g = params[:file][:tempfile]
      f.write g.read
    end

    maxid = FileEntry.maximum(:id) || 0
    entry = FileEntry.new
    entry.id = maxid + 1
    entry.userid = @u
    entry.filename = filename
    entry.upload_date = Time.now
    entry.size = File.size(save_path)
    entry.save
  else
    session[:error] = 'Upload failed'
    puts 'Upload failed'
  end

  redirect '/index'
end

post '/delete' do
  @u = session[:username]

  redirect '/badrequest' if @u.nil?

  file = params[:file]
  entry = FileEntry.find_by(filename: file)

  if entry && entry.userid == @u
    filepath = "./public/files/#{entry.filename}"
    File.delete(filepath) if File.exist?(filepath)
    entry.destroy
  else
    session[:error] = 'Delete failed'
    puts 'Delete failed'
  end

  redirect '/index'
end

get '/badrequest' do
  erb :badrequest
end
