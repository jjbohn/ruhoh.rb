require 'ruhoh/views/rmustache'

module Ruhoh::Views
  class Page < RMustache
    attr_reader :sub_layout, :master_layout
    attr_accessor :data
    
    def initialize(ruhoh, pointer_or_content)
      @ruhoh = ruhoh
      if pointer_or_content.is_a?(Hash)
        @data = @ruhoh.db.get(pointer_or_content)
        @data = {} unless @data.is_a?(Hash)

        raise "Page #{pointer_or_content['id']} not found in database" unless @data

        context.push(@data)
        @pointer = pointer_or_content
      else
        @content = pointer_or_content
        @data = {}
      end
    end
    
    def render_full
      process_layouts
      render(expand_layouts)
    end
    
    # Delegate #page to the kind of resource this view is modeling.
    def page
      return @page if @page
      collection = __send__(@pointer["resource"])
      @page = collection ? collection.new_model_view(data) : nil
    end

    def urls
      @ruhoh.db.urls
    end
    
    def content
      render(@content || @ruhoh.db.content(@pointer))
    end

    def partial(name)
      p = @ruhoh.db.partials[name.to_s]
      Ruhoh::Friend.say { yellow "partial not found: '#{name}'" } if p.nil?
      p
    end
    
    # Marks the active page if exists in the given pages Array
    def mark_active_page(pages)
      pages.each_with_index do |page, i| 
        next unless context["page"] && (page['id'] == context["page"]['id'])
        active_page = page.dup
        active_page['is_active_page'] = true
        pages[i] = active_page
      end
      pages
    end
    
    def to_json(sub_context)
      sub_context.to_json
    end
  
    def to_pretty_json(sub_context)
      JSON.pretty_generate(sub_context)
    end
    
    def debug(sub_context)
      Ruhoh::Friend.say { 
        yellow "?debug:"
        magenta sub_context.class
        cyan sub_context.inspect
      }

      "<pre>#{sub_context.class}\n#{sub_context.pretty_inspect}</pre>"
    end

    def raw_code(sub_context)
      code = sub_context.gsub('{', '&#123;').gsub('}', '&#125;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('_', "&#95;")
      "<pre><code>#{code}</code></pre>"
    end
    
    # Public: Formats the path to the compiled file based on the URL.
    #
    # Returns: [String] The relative path to the compiled file for this page.
    def compiled_path
      path = CGI.unescape(@data['url']).gsub(/^\//, '') #strip leading slash.
      path = "index.html" if path.empty?
      path += '/index.html' unless path =~ /\.\w+$/
      path
    end
    
    protected
    
    def process_layouts
      if @data['layout']
        @sub_layout = @ruhoh.db.layouts[@data['layout']]
        raise "Layout does not exist: #{@data['layout']}" unless @sub_layout
      end
    
      if @sub_layout && @sub_layout['data']['layout']
        @master_layout = @ruhoh.db.layouts[@sub_layout['data']['layout']]
        raise "Layout does not exist: #{@sub_layout['data']['layout']}" unless @master_layout
      end
      
      @data['sub_layout'] = @sub_layout['id'] rescue nil
      @data['master_layout'] = @master_layout['id'] rescue nil
      @data
    end
    
    # Expand the layout(s).
    # Pages may have a single master_layout, a master_layout + sub_layout, or no layout.
    def expand_layouts
      if @sub_layout
        layout = @sub_layout['content']

        # If a master_layout is found we need to process the sub_layout
        # into the master_layout using mustache.
        if @master_layout && @master_layout['content']
          layout = render(@master_layout['content'], {"content" => layout})
        end
      else
        # Minimum layout if no layout defined.
        layout = '{{{content}}}' 
      end
      
      layout
    end
    
  end #Page
end #Ruhoh