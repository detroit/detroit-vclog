require 'detroit/tool'

module Detroit

  # VCLog tool.
  def VClog(options={})
    VClog.new(options)
  end

  # VClog service generates changelogs from
  # SCM commit messages.
  #
  # TODO: Support multiple formats in one pass.
  class VClog < Tool

    #
    VALID_FORMATS = /^(html|yaml|json|xml|rdoc|md|markdown|gnu|txt|atom|rss|ansi)$/

    #
    VALID_TYPES = /^(log|rel|history|changelog)$/


    #  A T T R I B U T E S

    # Current version of project.
    attr_accessor :version

    # Changelog layout type (+changelog+ or +history+). Default is +changelog+.
    attr_reader :type

    # Output is either a file name with a clear extension to infer type
    # or a list of such file names, or a hash mapping file name to type.
    #
    #   output: NOTES.rdoc
    #
    #   output:
    #     - NOTES.rdoc
    #     - site/notes.html
    #
    #   output:
    #     NOTES: markdown
    #     site/notes.html: html
    #
    # Recognized formats include `html`, `xml`, `atom`, `rss`, `json`, `yaml`,
    # `rdoc`, `markdown` and `md`, `ansi`, `gnu` and `txt`.
    attr_accessor :output

    # Show revision/reference numbers (true/false)?
    attr_accessor :id

    # Some formats, such as +rdoc+, use a title field. Defaults to project title.
    attr_accessor :title

    # Some formats can reference an optional stylesheet (namely +xml+ and +html+).
    attr_accessor :style

    # Minimum change level to include.
    attr_accessor :level

    # Divide messages into change points (true/false)?
    attr_accessor :point

    # Reduced detail?
    attr_accessor :summary

    # Set output type.
    def type=(f)
      type = f.to_s.downcase
      if type !~ VALID_TYPES
        abort "Invalid vclog type - #{type}"
      end
      @type = type
    end


    #  A S S E M B L Y  M E T H O D S

    #
    def assemble?(station, options={})
      case station
      when :document then true
      when :reset    then true
      when :purge    then true
      end
    end

    #
    def assemble(station, options={})
      case station
      when :document then document
      when :reset    then reset
      when :purge    then purge
      end
    end


    #  S E R V I C E  M E T H O D S

    # TODO: Check the output files and see if they are older than
    # the current change log.
    #
    # @return [Boolean] whether output is up-to-date
    def current?
      false
      #output_mapping.each do |file, format|
      #  return false if outofdate?(file, *dnote_session.files)
      #else
      #  "VCLogs are current."
      #end
    end

    # Generate the log.
    def document
      output_mapping.each do |file, format, type|
        next unless verify_format(format, file)
        #file = File.join(output, fname)
        trace "vclog --#{type} -f #{format} >> #{file}"
        if dryrun?
          false # file hasn't changed
        else
          changed = save(file, format, type)
          if changed
            report "Updated " + relative_from_root(file)
          else
            report "Current " + relative_from_root(file)
          end
          changed
        end
      end
    end

    # Save changelog/history to +output+ file.
    def save(file, format, type)
      text = render(format, type)
      if File.exist?(file)
        return false if File.read(file) == text
      else
        dir = File.dirname(file)
        mkdir_p(dir) unless File.exist?(dir)
      end
      File.open(file, 'w'){ |f| f << text }
      return true
    end

    # Mark the output directory as out of date.
    def reset
      output_mapping.each do |file, format, type|
        if File.exist?(file)
          utime(0,0,file)
          report "Reset #{file}."
        end
      end
    end

    # TODO: anything to remove ?
    def clean
    end

    # Remove output directory output directory.
    def purge
      output_mapping.each do |file, format, type|
        if File.exist?(file)
          rm(file)
          report "Removed #{file}"
        end
      end
    end

    # Access to version control system.
    def repo
      @repo ||= VCLog::Repo.new(project.root.to_s)
    end

    # Convert log to desired format.
    def render(format, doctype)
      doctype = type if doctype.nil?
      doctype = 'history'   if doctype == 'rel'
      doctype = 'changelog' if doctype == 'log'

      options = {
        :type       => doctype,
        :format     => format,
        :stylesheet => style,
        :level      => level,
        :point      => point,
        :is         => id,
        :version    => version,
        :title      => title,
        :summary    => summary
      }

      repo.report(options)
    end

  private

    #
    def verify_format(format, file)
      if format !~ VALID_FORMATS
        report "Invalid format for `#{file}' - `#{fmt}'."   # report_error
        false
      else
        true
      end
    end

    # Convert output into a list of [file, format, type].
    #++
    # TODO: apply_naming_policy ?
    #--
    def output_mapping
      @output_mapping ||= (
        list = []
        case output
        when Array
          output.each do |path|
            list << [path, infer_format(path), infer_type(path)]
          end
        when String
          list << [output, infer_format(output), infer_type(output)]
        when Hash
          output.each do |path, format|
            list << [path, format, infer_type(path)]
          end
        end
        list
      )
    end

    #
    def infer_format(file)
      fmt = File.extname(file).sub('.','')
      fmt = DEFAULT_FORMAT if type.empty?
      fmt
    end

    #
    def infer_type(file)
      case file
      when /history/i
        'history'
      when /log/
        'changelog'
      else
        type
      end
    end

    #
    def relative_from_root(path)
      begin
        Pathname.new(path).relative_path_from(project.root)
      rescue
        path
      end
    end

    #
    def initialize_requires
      require 'vclog'
    end

    #
    def initialize_defaults
      @version    = metadata.version
      @title      = metadata.title
      @output     = project.log + 'changelog.atom'
      @type       = 'log'
      @level      = 0
      @summary    = false
    end

    ## Returns changelog or history depending on type selection.
    #def log
    #  @log ||= (
    #    case type
    #    when 'log', 'changelog'
    #      log = repo.changelog
    #    when 'rel', 'history'
    #      log = repo.history(:title=>title, :version=>version)
    #    else
    #      log = repo.changelog
    #    end
    #  )
    #end

    #def vclog_config
    #  @vclog_config ||= (
    #    vcf = VCLog::Config.new(project.root.to_s)
    #    vcf.level = level
    #    vcf
    #  )
    #end

=begin
    # Convert formats into a hash of `format => fname`.
    def formats_mapping(formats=nil)
      formats ||= self.formats
      case formats
      when String
        formats_mapping([formats])
      when Array
        h = {}
        formats.each do |format|
          h[format] = infer_output_fname(format, type)
        end
        h
      when Hash
        formats
      else
        raise ArgumentError, "invalid formats field -- #{formats.inspect}"
      end
    end

    #
    def infer_output_fname(format, type)
      fname = case type
              when 'rel', 'history'
                'history'
              else
                'changelog'
              end 
      #apply_naming_policy(fname, log_format.downcase)
      ext = format_extension(format)
      fname + ext
    end

    #
    def format_extension(format)
      ".#{format}"
    end

#    #
#    def valid?
#      return false unless output.all?{ |x, f| f =~ VALID_FORMATS }
#      return false unless type =~ VALID_TYPES
#      return true
#    end

=end

  public

    def self.man_page
      File.dirname(__FILE__)+'/../man/detroit-vclog.5'
    end

  end

end
