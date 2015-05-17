class Filetree
  include ActiveModel::Model
  
  attr_accessor :tree, :latest_cursor
  attr_reader   :cloud_account
  
  ROOT = '/'
  
  def initialize(cloud_account)
    @cloud_account        = cloud_account
    @latest_cursor, @tree = Filetree.load_tree(@cloud_account)
  end
  
  def update(entry)
    path, metadata = entry
    branch, leaf   = split_path(path)
    
    unless metadata.nil?
      children = @tree
      branch.each do |part|
        node = get_or_create_child(children, part)
        unless node.is_folder?
          node.content = []
        end
        children = node.content
      end
    
      node = get_or_create_child(children, leaf)
      if metadata[:is_dir]
        node.content = [] unless node.is_folder?
      else
        node.content = metadata
      end
    else
      children = @tree
      missing_parent = false
      branch.each do |part|
        node = children.select {|node| node.name == part}.first
        if node.nil? || !node.is_folder?
          missing_parent = true
          break
        end
        children = node.content
      end
      unless missing_parent
        children.delete_if{|node| node.name == leaf}
      end
    end
    
    save
  end
  
  def reset
    @tree.clear
    save
  end
  
  def find(path)
    branch, leaf = split_path(path)
    tree = @tree
    branch.each do |part|
      result = search(tree, part).first
      if result.nil? || !result.is_folder?
        return false
      else
        tree = result.content
      end
    end
    tree = @tree if tree.empty?
    if leaf.nil?
      content = tree.map{ |node| 
        if node.is_folder?
          { "path"     => File.join(ROOT, node.name), 
            "is_dir"   => true }
        else
          node.content
        end
        node 
      }
      Node.new("", content)
    else
      res = search(tree, leaf).first
    end
    res
  end
  
  def search(folder, term)
    folder.select{|child| child.name == term}
  end
  
  def get_or_create_child(children, name)
    child = children.select {|node| node.name == name}.first
    
    if child.blank?
      child = Node.new(name, nil)
      children << child
    end 
    child
  end
  
  def self.cache_file(cloud_account)
    "#{cloud_account}_cache"
  end
  
  def split_path(path)
    bad, *parts = path.split '/'
    [parts, parts.pop]
  end
  
  def self.load_tree(cloud_account)
    name  = Filetree.cache_file(cloud_account)
    cache = Rails.cache.fetch(name) || false
    if cache
      content = JSON.parse(cache, max_nesting: false)
      latest_cursor, tree = content
      tree = Node.from_json_content(tree)
      [latest_cursor, tree]
    else
      [nil, []]
    end
  end
  
  def save
    name = Filetree.cache_file(@cloud_account)
    content = @latest_cursor, Node.to_json_content(@tree)
    Rails.cache.delete(name)

    Rails.cache.fetch(name, expires_in: 2.hours) do
      JSON.pretty_generate(content, max_nesting: false)
    end
  end
end
