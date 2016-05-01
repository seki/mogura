class Card
  @@ser = 0

  def self.create_from_line(line)
    ary = line.split(' ')
    case ary[0]
    when 'break'
      self.break
    when 'map'
      self.map
    when 'kanban'
      self.kanban
    when 'candy'
      self.candy
    when 'gift'
      self.gift
    else
      self.item(ary[0], ary[1], ary[2].to_i)
    end
  end
  
  def self.break
    self.new([:break], "\u{2668}", 5, :recovery, 2)
  end

  def self.map
    self.new([:map], 'map', 4, :search_candy, 2)
  end

  def self.kanban
    self.new([:kanban], 'kanban', 2, :search_gift, 1)
  end

  def self.candy
    self.new([:candy], "candy", 2, :get, 2)
  end

  def self.gift
    self.new([:gift], "gift", 2, :get, 1)
  end

  def self.item(color, item, cost)
    e_color = case color
              when 'red'
                "\u{1f49c}"
              when 'blue'
                "\u{1f499}"
              when 'yellow'
                "\u{1f49b}"
              end
    e_item = case item
              when 'glasses'
                "\u{1F576}"
              when 'necklace'
                "\u{1f4ff}"
              when 'bag'
                "\u{1f45c}"
              end

    name = "#{e_color}  #{e_item}  #{cost}"
    case cost
    when 1
      self.new([color.intern, item.intern], name, cost, :get, 2)
    when 2
      self.new([color.intern, item.intern], name, cost, :get, 3)
    when 3
      self.new([color.intern, item.intern], name, cost, :get, 5)
    when 4
      self.new([color.intern, item.intern], name, cost, :get, 7, true)
    end
  end

  def initialize(kind, name, cost, action, open, spread=false)
    @kind = kind
    @@ser += 1
    @ser = @@ser
    @name = name
    @cost = cost
    @action = action
    @open = open
    @spread = spread
  end
  attr_reader :ser, :name, :action

  def kind; @kind[0]; end

  def to_a
      [@name, "cost: #{@cost}", @action.to_s,
       (@spread ? 'spread' : 'open') +  ": #{@open}"]
  end

  def to_s
    to_a.join("\n ")
  end

  def do_phase(deck, n, &blk)
    case n
    when 0
      deck.cost(@cost)
    when 1
      deck.send(@action, self)
    when 2
      if @spread
        deck.spread(@open, &blk)
      else
        deck.open(@open, &blk)
      end
    end
  end
end

class Deck
  class EmptyError < RuntimeError; end

  def initialize
    @ary = []
    fp = DATA
    while line = fp.gets
      @ary << Card.create_from_line(line.chomp)
    end
    @ary = @ary.sort_by {rand}
    @lost = []
    @trash = []
    @bag = []
    @current = nil
    @phase = nil
    @code = []
  end

  def size
    @ary.size
  end

  def show(n)
    @ary.shift(n).sort_by {|x| x.name}
  end

  def trash(card)
    @trash << card
  end

  def cost(n)
    raise EmptyError if @ary.size < n
    @lost.push(* @ary.shift(n))
    @phase = 1
  end

  def open(n)
    raise EmptyError if @ary.empty?
    hands = show(n)
    card = yield(hands)
    hands.each do |it|
      trash(it) unless it == card
    end
    @current = card
    @phase = 0
    card
  end
  
  def spread(n)
    raise EmptyError if @ary.empty?
    hands = show(n)
    card = yield(hands)
    hands.each do |it|
      @ary << it unless it == card
    end
    @ary = @ary.sort_by {rand}
    @current = card
    @phase = 0
    card
  end

  def get(card)
    @bag << card
    @phase = 2
  end

  def recovery(card)
    @ary = @ary + @trash
    @trash = []
    @ary = @ary.sort_by {rand}
    @bag << card
    @phase = 2
  end

  def search_candy(card)
    puts "## deck"
    @ary.sort_by {|x| x.name}.chunk {|x| x.name[0]}.each {|first, ary|
      puts "* #{ary.map{|x| x.name}.join(' ')}"
    }
    ary = []
    candy = []
    @ary.each do |it|
      if it.kind == :candy && candy.size < 2
        candy << it
      else
        ary << it
      end
    end
    @ary = ary.sort_by {rand}
    @bag = @bag + candy
    @bag << card
    @phase = 2
  end

  def search_gift(card)
    puts "## deck"
    @ary.sort_by {|x| x.name}.chunk {|x| x.name[0]}.each {|first, ary|
      puts "* #{ary.map{|x| x.name}.join(' ')}"
    }
    ary = []
    gift = []
    @ary.each do |it|
      if it.kind == :gift && gift.size < 1
        gift << it
      else
        ary << it
      end
    end
    @ary = ary.sort_by {rand}
    @bag = @bag + gift
    @bag << card
    @phase = 2
  end

  def do_candy
    found = @bag.find {|it| it.kind == :candy}
    return unless found
    @bag.delete(found)
    @trash << found
    @lost = @lost.sort_by {rand}
    ary = @lost.shift(4)
    @ary = (@ary + ary).sort_by {rand}
  end

  def do_gift
    found = @bag.find {|it| it.kind == :gift}
    return unless found
    @bag.delete(found)
    @trash << found
    @lost = @lost.sort_by {rand}
    ary = @lost.shift(5)
    @ary = (@ary + ary).sort_by {rand}
  end

  def prompt(&blk)
    puts
    puts "[deck: #{@ary.size} trash: #{@trash.size} lost: #{@lost.size} bag: #{@bag.size} (#{@ary.size + @trash.size + @lost.size + @bag.size})]"
    puts '## trash'
    @trash.sort_by {|x| x.name}.chunk {|x| x.name[0]}.each {|first, ary|
      puts "* #{ary.map{|x| x.name}.join(' ')}"
    }
    puts
    puts '## bag'
    @bag.sort_by {|x| x.name}.chunk {|x| x.name[0]}.each {|first, ary|
      puts "* #{ary.map{|x| x.name}.join(' ')}"
    }

    puts
    @current.to_a.each_with_index do |str, n|
      if n == @phase + 1
        puts str + " **"
      else
        puts str
      end
    end
    while true
      puts "[deck: #{@ary.size} trash: #{@trash.size} lost: #{@lost.size} bag: #{@bag.size} (#{@ary.size + @trash.size + @lost.size + @bag.size})]"
      cmd = gets.chomp
      case cmd
      when 'c'
        do_candy
      when 'g'
        do_gift
      when 't'
        puts '## trash'
        @trash.sort_by {|x| x.name}.chunk {|x| x.name[0]}.each {|first, ary|
          puts "* #{ary.map{|x| x.name}.join(' ')}"
        }
        puts
      else
        break
      end
    end
    begin
      @current.do_phase(self, @phase, &blk)
    rescue EmptyError
      @bag.sort_by {|x| x.name}.each do |card|
        puts "* #{card.name}"
      end
      exit
    end
  end
end

deck = Deck.new

deck.open(3) do |hands|
  hands.each_with_index do |card, n|
    puts "- #{n}: #{card.name}"
  end
  n = 0
  while true
    n = Integer(gets.chomp) rescue nil
    next unless n
    break if (0...(hands.size)) === n
  end
  hands[n]
end

while true
  deck.prompt do |hands|
    hands.each_with_index do |card, n|
      puts "- #{n}: #{card.name}"
    end
    n = 0
    while true
      n = Integer(gets.chomp) rescue nil
      next unless n
      break if (0...(hands.size)) === n
    end
    hands[n]
  end
end

__END__
break
break
break
break
break
break
yellow glasses 1
yellow necklace 1
yellow bag 1
yellow glasses 4
yellow necklace 4
yellow bag 4
yellow glasses 2
yellow necklace 2
yellow bag 2
yellow glasses 3
yellow necklace 3
yellow bag 3
blue glasses 1
blue necklace 1
blue bag 1
blue glasses 4
blue necklace 4
blue bag 4
blue glasses 3
blue necklace 3
blue bag 3
blue glasses 2
blue necklace 2
blue bag 2
red glasses 2
red necklace 2
red bag 2
red glasses 4
red necklace 4
red bag 4
red glasses 1
red necklace 1
red bag 1
red glasses 3
red necklace 3
red bag 3
candy
candy
candy
candy
candy
candy
candy
candy
gift
gift
gift
gift
map
map
map
map
kanban
kanban
