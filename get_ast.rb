require "kramdown"

# Lis ton markdown (ici depuis un fichier, mais tu peux mettre le texte brut dans la variable)
markdown = File.read("foo.md")

doc = Kramdown::Document.new(markdown)
root = doc.root

# Fonction récursive pour afficher l’arbre avec indentation
def dump_ast(element, indent = 0)
  spacer = "  " * indent
  info = "#{element.type}"
  info += "(level=#{element.options[:level]})" if element.type == :header
  info += " value='#{element.value}'" if element.value.is_a?(String) && !element.value.strip.empty?

  puts "#{spacer}- #{info}"

  element.children.each do |child|
    dump_ast(child, indent + 1)
  end
end

# Lance le dump depuis la racine
dump_ast(root)

