class Cache
  def initialize options = {}
    @tmp_dir = 'cache'
    @force = options[:force]
  end

  def get key
    file_name = File.join @tmp_dir, key
    if File.exists? file_name
      begin
        Marshal.load File.open(file_name).read
      rescue => e
        puts e.inspect
        puts e.backtrace.join "\n"
        nil
      end
    else
      nil
    end
  end

  def fetch key, options = {}
    force = options[:force].nil? ? @force : options[:force]
    file_name = File.join @tmp_dir, key
    file_dir = File.dirname file_name
    Dir.mkdir file_dir unless File.directory? file_dir
    File.delete(file_name) if force && File.exists?(file_name)
    unless File.exists? file_name
      File.open file_name, 'w' do |file|
        file.write Marshal.dump(yield)
      end
    end
    Marshal.load File.open(file_name).read
  end
end
