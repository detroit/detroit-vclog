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

    # Current version of project.
    attr_accessor :version

    # Changelog layout type (+changelog+ or +history+). Default is +changelog+.
    attr_reader :type

    # Changelog format(s). Supports the following formats: `html`, `xml`,
    # `atom`, `rss`, `json`, `yaml`, `rdoc`, `markdown` and `md`, `ansi`,
    # `gnu` and `txt`.
    #
    attr_accessor :formats

    # Output directory in which store rendered files.
    attr_accessor :output

    # Show revision numbers (true/false)?
    attr_accessor :rev

    # Some formats, such as +rdoc+, use a title field. Defaults to project title.
    attr_accessor :title

    # Some formats can reference an optional stylesheet (namely +xml+ and +html+).
    attr_accessor :style

    # Minimum change level to include.
    attr_accessor :level

    # Reduced detail?
    attr_accessor :summary

    #
    def initialize_defaults
      @version    = metadata.version
      @title      = metadata.title
      @output     = project.log
      @formats    = 'atom'
      @type       = 'log'
      @level      = 0
      @summary    = false
    end

    #
    VALID_FORMATS = /^(html|yaml|json|xml|rdoc|md|markdown|gnu|txt|atom|rss|ansi)$/

    #
    VALID_TYPES = /^(log|rel|history|changelog)$/

    #
    def valid?
      return false unless formats.all?{ |f| f =~ VALID_FORMATS }
      return false unless type   =~ VALID_TYPES
      return true
    end

    #
    alias_method :format=, :formats=

    #
    def type=(f)
      @type = f.to_s.downcase
    end

    #++
    # TODO: apply_naming_policy ?
    #--

    # Generate the log.
    def document
      require 'vclog'
      formats_mapping.each do |format, fname|
        file = File.join(output, fname)
        if dryrun?
          report "# vclog --#{type} -f #{format} >> #{file}"
          false # file hasn't changed
        else
          changed = save(format, file)
          if changed
            report "Updated #{relative_from_root(file)}"
          else
            report "Current #{relative_from_root(file)}"
          end
          changed
        end
      end
    end

    # Save changelog/history to +output+ file.
    def save(format, output)
      text = render(format)
      if File.exist?(output)
        return false if File.read(output) == text
      else
        dir = File.dirname(output)
        mkdir_p(dir) unless File.exist?(dir)
      end
      File.open(output, 'w'){ |f| f << text }
      return true
    end

    # Mark the output directory as out of date.
    def reset
      if directory?(output)
        utime(0, 0, output)
        report "Reset #{output}" #unless trial?
      end
    end

    # TODO: anything to remove ?
    def clean
    end

    # Remove output directory output directory.
    def purge
      if directory?(output)
        rm_r(output)
        status "Removed #{output}" unless trial?
      end
    end

    ## Returns changelog or history depending on type selection.
    #def log
    #  @log ||= (
    #    case type
    #    when 'log', 'changelog'
    #      log = vcs.changelog
    #    when 'rel', 'history'
    #      log = vcs.history(:title=>title, :version=>version)
    #    else
    #      log = vcs.changelog
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

    # Access to version control system.
    def vcs
      #@vcs ||= VCLog::VCS.new #(self)
      #@vcs ||= VCLog::Adapters.factory(vclog_config)
      @vcs ||= VCLog::Repo.new(project.root.to_s, :level=>level)
    end

    # Convert log to desired format.
    def render(format)
      doctype = type
      doctype = 'history'   if doctype == 'rel'
      doctype = 'changelog' if doctype == 'log'

      options = {
        :stylesheet => style,
        :revision   => rev,
        :version    => version,
        :title      => title,
        :extra      => !summary
      }

      vcs.display(doctype, format, options)
    end

  private

    #
    def format_extension(format)
      ".#{format}"
    end

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
    def relative_from_root(path)
      begin
        Pathname.new(path).relative_path_from(project.root)
      rescue
        path
      end
    end

  end

end

