require 'sinatra'

set :environment, :production
enable :sessions

get '/' do
  images_name = Dir.glob("public/files/*")
  @images_path = []

  images_name.each do |a|
    file_name = File.basename(a)
    file_size = File.size(a)
    file_mtime = File.mtime(a)
    # @images_path << a.gsub("public/files/", "")
    @images_path << { name: file_name, size: file_size, mtime: file_mtime }
    puts file_size
    puts file_mtime
  end

  @error = session.delete(:error)
  erb :index
end

post '/upload' do
  s = params[:file]
  if s != nil
    save_path = "./public/files/#{params[:file][:filename]}"

    File.open(save_path, 'wb') do |f|
      g = params[:file][:tempfile]
      f.write g.read
    end
  else
    session[:error] = "Upload failed"
    puts "Upload failed"
  end

  redirect '/'
end
