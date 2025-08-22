require "pp"
require "uri"
require_relative "Parsers/Parser"


module Jekyll
    class CustomGenerator < Generator

        safe true
        priority :high

        def generate(site)

            site.pages.each do |page|

                next unless page.data["layout"] == "tabs"

                page.content = "::CUSTOM_MD::\n\n" + page.content

                markdown = File.read(page.path)

                root = Kramdown::Document.new(markdown).root

                root = preprocess_tree(root)

                content = {}
                indent = 0

                last_tab = nil
                last_section = nil
                last_card = nil

                skip_nodes = 0

                root.children.each_with_index do |node, index|

                    if skip_nodes > 0

                        skip_nodes = [0, skip_nodes - 1].max
                        next

                    end

                    case node.type
                    when :header

                        level = node.options[:level]

                        case level
                        when 1

                            # Page Header
                            content["subheader"] = {
                                "title" => Parser.parse(node),
                            }
                            indent = 1

                        when 2

                            # Tab header
                            content["tabs"] ||= []
                            last_tab = {
                                "title" => Parser.parse(node),
                            }
                            content["tabs"] << last_tab
                            indent = 2

                        when 3

                            # Section header
                            last_tab["sections"] ||= []
                            last_section = {}

                            template = node.attr["data-template"]

                            if template

                                # Parse the whole section using custom parser.
                                # Skip parsing of the next nodes that already
                                # are in this custom section

                                last_section["template"] = template

                                parser_name = template
                                    .split("-").map(&:capitalize).join

                                require_relative "Parsers/#{parser_name}.rb"
                                sectionParser = Object.const_get(parser_name)

                                section_nodes = [node]

                                root.children[(index + 1)..-1].each do |node|

                                    break if node.type == :header &&
                                        node.options[:level] <= 3
                                    section_nodes << node
                                    skip_nodes += 1

                                end

                                last_section.merge!(
                                    sectionParser.parse(section_nodes),
                                )

                            else

                                last_section["title"] = Parser.parse(node)

                            end

                            last_tab["sections"] << last_section

                            indent = 3

                        when 4

                            # Section subheader
                            last_section["desc"] ||= []
                            last_section["desc"] << {
                                "type" => "header",
                                "text" => Parser.parse(node),
                            }

                        when 5

                            # Card header
                            last_section["cards"] ||= []
                            last_card = {
                                "title" => Parser.parse(node),
                            }
                            last_section["cards"] << last_card
                            indent = 4

                        end

                    when :p

                        case indent
                        when 1

                            # Subheader description
                            content["subheader"]["description"] ||= []
                            content["subheader"]["description"] << {
                                "paragraph" => Parser.parse(node),
                            }

                        when 2

                            # Tab description
                            last_tab["desc"] ||= []
                            last_tab["desc"] << {
                                "paragraph" => Parser.parse(node),
                            }

                        when 3

                            # Section description
                            last_section["desc"] ||= []
                            last_section["desc"] << {
                                "type" => "paragraph",
                                "text" => Parser.parse(node),
                            }


                        when 4

                            # Card text
                            last_card["text"] ||= []
                            last_card["text"] << {
                                "paragraph" => Parser.parse(node),
                            }

                        end

                    when :ul

                        if indent == 4

                            # Card tags
                            last_card["tags"] ||= []
                            node.children.each do |child|
                                last_card["tags"] << Parser.parse(child)
                            end

                        end

                    end

                end

                # pp content
                page.data["structured_content"] = content

            end

        end


        def preprocess_tree(node)

            node.children.each { |child| preprocess_tree(child) }

            # Remove blank nodes
            node.children.reject! { |child| child.type == :blank }

            # Classify link nodes and add target attribute for external links
            if node.type == :a

                node.attr["class"] ||= ""

                if node.attr["href"]

                    target_domain = URI.parse(node.attr["href"])&.host

                    if target_domain && target_domain != @site_domain

                        node.attr["target"] ||= "_blank"

                    end

                end

                if node.attr["data-display"] == "button"

                    node.attr["class"] << " button medium tertiary"

                else

                    node.attr["class"] << " inline-link"

                end

            end

            return node

        end

    end
end
