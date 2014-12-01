module Temple
  module HTML
    # @api public
    class Pretty < Fast
      define_options :indent => '  ',
                     :pretty => true,
                     :indent_tags => %w(article aside audio base body datalist dd div dl dt
                                        fieldset figure footer form head h1 h2 h3 h4 h5 h6
                                        header hgroup hr html li link meta nav ol option p
                                        rp rt ruby section script style table tbody td tfoot
                                        th thead tr ul video doctype).freeze,
                     :pre_tags => %w(code pre textarea).freeze

      def initialize(opts = {})
        super
        @indent_next = nil
        @indent = 0
        @pretty = options[:pretty]
        @pre_tags = @format != :xml && Regexp.new(options[:pre_tags].map {|t| "<#{t}" }.join('|'))
        puts "hi"
      end

      def call(exp)
        @pretty ? [:multi, preamble, compile(exp)] : super
      end

      def on_static(content)
        return [:static, content] unless @pretty
        if !@pre_tags || @pre_tags !~ content
          content = content.sub(/\A\s*\n?/, "\n") if @indent_next
          content = content.gsub("\n", indent)
        end
        @indent_next = false
        [:static, content]
      end

      def on_dynamic(code)
        return [:dynamic, code] unless @pretty
        tmp = unique_name
        indent_code = ''
        indent_code << "#{tmp} = #{tmp}.sub(/\\A\\s*\\n?/, \"\\n\"); " if @indent_next
        indent_code << "#{tmp} = #{tmp}.gsub(\"\\n\", #{indent.inspect}); "
        if ''.respond_to?(:html_safe)
          safe = unique_name
          # we have to first save if the string was html_safe
          # otherwise the gsub operation will lose that knowledge
          indent_code = "#{safe} = #{tmp}.html_safe?; #{indent_code}#{tmp} = #{tmp}.html_safe if #{safe}; "
        end
        @indent_next = false
        [:multi,
         [:code, "#{tmp} = (#{code}).to_s"],
         [:code, @pre_tags ? "if #{@pre_tags_name} !~ #{tmp}; #{indent_code}end" : indent_code],
         [:dynamic, tmp]]
      end

      def on_html_doctype(type)
        return super unless @pretty
        [:multi, [:static, tag_indent('doctype')], super]
      end

      def on_html_comment(content)
        return super unless @pretty
        result = [:multi, [:static, tag_indent('comment')], super]
        @indent_next = false
        result
      end

      def on_html_tag(name, attrs, content = nil)
        return super unless @pretty

        name = name.to_s
        closed = !content || (empty_exp?(content) && options[:autoclose].include?(name))

        @pretty = false
        result = [:multi, [:static, "#{tag_indent(name)}<#{name}"], compile(attrs)]
        result << [:static, (closed && @format != :html ? ' /' : '') + '>']

        @pretty = !@pre_tags || !options[:pre_tags].include?(name)
        if content
          @indent += 1
          result << compile(content)
          @indent -= 1
        end
        unless closed
          indent = tag_indent(name)
          result << [:static, "#{content && !empty_exp?(content) ? indent : ''}</#{name}>"]
        end
        @pretty = true
        result
      end

      protected

      def preamble
        return [:multi] unless @pre_tags
        @pre_tags_name = unique_name
        [:code, "#{@pre_tags_name} = /#{@pre_tags.source}/"]
      end

      def indent
        "\n" + (options[:indent] || '') * @indent
      end

      # Return indentation before tag
      def tag_indent(name)
        if @format == :xml
          flag = @indent_next != nil
          @indent_next = true
        else
          flag = @indent_next != nil && (@indent_next || options[:indent_tags].include?(name))
          @indent_next = options[:indent_tags].include?(name)
        end
        flag ? indent : ''
      end
    end
  end
end
