def denied(label)
  begin
    yield
  rescue Errno::EPERM, Errno::EACCES
    puts "#{label}=DENIED"
    return
  end
  abort "#{label}=UNEXPECTEDLY_ALLOWED"
end
legacy, host_file, project_file = ARGV
# No values are read or printed; denied stat proves Flutter's existence probe fails.
denied('LEGACY_STAT') { File.stat(legacy) }
denied('LEGACY_READ') { File.open(legacy, File::RDONLY) { |f| f.read(1) } }
# O_WRONLY without O_TRUNC/O_CREAT never changes this existing file.
denied('HOST_WRITE_OPEN') { File.open(host_file, File::WRONLY) { |f| f.close } }
File.write(project_file, 'project-only probe')
abort 'project file mismatch' unless File.read(project_file) == 'project-only probe'
File.delete(project_file)
puts 'PROJECT_READ_WRITE=ALLOWED'
