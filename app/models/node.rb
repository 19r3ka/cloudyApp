class Node
  include ActiveModel::Model
#  
#  Nodes are used to build 
#  filetrees specific to the
#  user's cloud storage structure
#  

  attr_accessor :name, :content
  
  def initialize(name, content)
    @name          = name
    @content       = content
  end
  
  def is_folder?
    @content.is_a? Array
  end
  
  def to_json
    {@name => Node.to_json_content(@content)}
  end
  
  def self.from_json(jnode)
    name, content = jnode.flatten
    name = "/" if name.blank?
    Node.new(name, Node.from_json_content(content))
  end
  
  def self.to_json_content(content)
    if content.is_a? Array
      content.map { |child| child.to_json }
    else
      content
    end
  end
  
  def self.from_json_content(jcontent)
    if jcontent.is_a? Array
      jcontent.map { |jchild| Node.from_json(jchild)}
    else
      jcontent
    end
  end
  
end
