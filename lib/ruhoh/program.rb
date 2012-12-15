class Ruhoh
  module Program
    
    # Public: A program for running ruhoh as a rack application
    # which renders singular pages via their URL.
    # 
    # Examples
    #
    #  In config.ru:
    #
    #   require 'ruhoh'
    #   run Ruhoh::Program.preview
    #
    # Returns: A new Rack builder object which should work inside config.ru
    def self.preview(opts={})
      opts[:watch] ||= true
      opts[:env] ||= 'development'
      
      ruhoh = Ruhoh.new
      ruhoh.setup
      ruhoh.env = opts[:env]
      ruhoh.setup_paths
      ruhoh.setup_plugins unless opts[:enable_plugins] == false

      # initialize the routes dictionary
      ruhoh.db.pages
      ruhoh.db.posts
      
      Ruhoh::Watch.start(ruhoh) if opts[:watch]
      Rack::Builder.new {
        use Rack::Lint
        use Rack::ShowExceptions
        
        ruhoh.db.urls.each do |name, url|
          next if ["base_path", "javascripts", "stylesheets"].include?(name)
          next unless ruhoh.resources.exists?(name)
          map url do
            if ruhoh.resources.previewer?(name)
              run ruhoh.resources.load_previewer(name)
            else
              run Rack::File.new(File.join(ruhoh.paths.base, ruhoh.db.paths[name]))
            end
          end
        end
        
        map '/' do
          run PagePreviewer.new(ruhoh)
        end
      }
    end
    
    # Public: Rack application used to render singular pages via their URL.
    class PagePreviewer
    
      def initialize(ruhoh)
        @ruhoh = ruhoh
      end
    
      def call(env)
        return favicon if env['PATH_INFO'] == '/favicon.ico'

        # Always remove trailing slash if sent unless it's the root page.
        env['PATH_INFO'].chomp!("/") unless env['PATH_INFO'] == "/"
        
        pointer =  @ruhoh.db.routes[env['PATH_INFO']]
        raise "Page id not found for url: #{env['PATH_INFO']}" unless pointer
        page = @ruhoh.page(pointer)
        [200, {'Content-Type' => 'text/html'}, [page.render_full]]
      end
    
      def favicon
        [200, {'Content-Type' => 'image/x-icon'}, ['']]
      end

    end
    
    # Public: A program for compiling to a static website.
    # The compile environment should always be 'production' in order
    # to properly omit drafts and other development-only settings.
    def self.compile(target)
      ruhoh = Ruhoh.new
      ruhoh.setup
      ruhoh.env = 'production'
      ruhoh.setup_paths
      ruhoh.setup_plugins
      
      if target
        ruhoh.paths.compiled = File.expand_path(target)
      elsif ruhoh.config["compiled"]
        ruhoh.paths.compiled = ruhoh.config["compiled"]
      end
      
      Ruhoh::Compiler.compile(ruhoh)
    end
    
  end #Program
end #Ruhoh