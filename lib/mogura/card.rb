class Card
  @@ser = 0

  ORDER = [:candy, :gift, :map, :kanban, :break, :yellow, :red, :blue]

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
    @order = [ORDER.index(kind[0]), kind[1], @cost] 
  end
  attr_reader :ser, :name, :action, :order, :kind, :cost

  def candy?
    @kind[0] == :candy
  end

  def gift?
    @kind[0] == :gift
  end

  def to_a
      [@name, "cost: #{@cost}", @action.to_s,
       (@spread ? 'spread' : 'open') +  ": #{@open}"]
  end

  def to_s
    to_a.join("\n ")
  end

  def todo
    [[:cost, @cost],
     [@action, self],
     [:show, @open],
     [(@spread ? :spread_else : :outlet_else), nil]]
  end
end

class Deck
  class EmptyError < RuntimeError; end

  CARDS = <<EOS
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
blue glasses 2
blue necklace 2
blue bag 2
blue glasses 1
blue necklace 1
blue bag 1
blue glasses 4
blue necklace 4
blue bag 4
blue glasses 3
blue necklace 3
blue bag 3
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
EOS

  @@cards = CARDS.split("\n").map do |line|
    Card.create_from_line(line.chomp)
  end

  def initialize
    @ary = @@cards.sort_by {rand}
    @lost = []
    @trash = []
    @bag = []
    @current = nil
    @code = []
    @hand = nil
    @todo = [[:show, 3], [:outlet_else, nil]]
    show(3)
  end
  attr_reader :ary, :lost, :bag, :current
  attr_reader :hand

  def prompt
    @todo.first
  end

  def outlet
    @trash
  end

  def size
    @ary.size
  end

  def show(n)
    raise EmptyError if @ary.empty?
    @hand = @ary.shift(n).sort_by {|x| x.order}
  ensure
    @todo.shift
  end

  def trash(card)
    @trash << card
  end

  def cost(n)
    raise EmptyError if @ary.size < n
    @lost.push(* @ary.shift(n))
  ensure
    @todo.shift
  end

  def outlet_else(card)
    @hand.each do |it|
      trash(it) unless it == card
    end
    @hand = nil
    @current = card
    @todo = card.todo
  end

  def spread_else(card)
    @hand.each do |it|
      @ary << it unless it == card
    end
    @hand = nil
    @current = card
    @todo = card.todo
  end

  def get(card)
    @bag << card
  ensure
    @current = nil
    @todo.shift
  end

  def recovery(card)
    @ary = @ary + @trash
    @trash = []
    @ary = @ary.sort_by {rand}
    @bag << card
  ensure
    @current = nil
    @todo.shift
  end

  def search_candy(card)
    puts "## deck"
    @ary.sort_by {|x| x.order}.chunk {|x| x.name[0]}.each {|first, ary|
      puts "* #{ary.map{|x| x.name}.join(' ')}"
    }
    ary = []
    candy = []
    @ary.each do |it|
      if it.candy? && candy.size < 2
        candy << it
      else
        ary << it
      end
    end
    @ary = ary.sort_by {rand}
    @bag = @bag + candy
    @bag << card
  ensure
    @current = nil
    @todo.shift
  end

  def search_gift(card)
    puts "## deck"
    @ary.sort_by {|x| x.order}.chunk {|x| x.name[0]}.each {|first, ary|
      puts "* #{ary.map{|x| x.name}.join(' ')}"
    }
    ary = []
    gift = []
    @ary.each do |it|
      if it.gift? && gift.size < 1
        gift << it
      else
        ary << it
      end
    end
    @ary = ary.sort_by {rand}
    @bag = @bag + gift
    @bag << card
  ensure
    @current = nil
    @todo.shift
  end

  def do_candy
    found = @bag.find {|it| it.candy?}
    return unless found
    @bag.delete(found)
    @trash << found
    @lost = @lost.sort_by {rand}
    ary = @lost.shift(4)
    @ary = (@ary + ary).sort_by {rand}
  end

  def do_gift
    found = @bag.find {|it| it.gift?}
    return unless found
    @bag.delete(found)
    @trash << found
    @lost = @lost.sort_by {rand}
    ary = @lost.shift(5)
    @ary = (@ary + ary).sort_by {rand}
  end
end

class TestUI
  def initialize(deck)
    @deck = deck
  end

  def entrance
    @deck.ary
  end

  def cost_area
    @deck.lost
  end

  def outlet
    @deck.outlet
  end

  def memory
    @deck.bag
  end

  def emoji(klass)
    case klass
    when :red
      "\u{1f49c}"
    when :blue
      "\u{1f499}"
    when :yellow
      "\u{1f49b}"
    when :glasses
      "\u{1F576}"
    when :necklace
      "\u{1f4ff}"
    when :bag
      "\u{1f45c}"
    else
      klass.to_s
    end
  end

  def cards_to_summary(first, ary)
    case first
    when :red, :yellow, :blue
      (['*', emoji(first), ''] + ary.map {|x| "#{emoji(x.kind[1])}  #{x.cost}"}).join(' ')
    else
      "* #{ary.map{|x| x.name}.join(' ')}"
    end
  end

  def area_summary(area)
    area.sort_by {|x| x.order}.chunk {|x| x.kind[0]}.each {|first, ary|
      puts cards_to_summary(first, ary)
    }
  end

  def show_hands
    @deck.hand.each_with_index do |card, n|
      puts "- #{n}: #{card.name}"
    end
    @deck.size
  end

  def prompt
    puts
    puts '## trash'
    area_summary(outlet)

    puts
    puts '## bag'
    area_summary(memory)

    if @deck.current 
      puts
      puts @deck.current.to_s 
    end

    kind, opt = @deck.prompt
    case kind
    when :spread_else, :outlet_else
      show_hands
    else
      puts "[#{kind}] / Candy / Gift"
    end

    puts "[deck: #{entrance.size} trash: #{outlet.size} lost: #{cost_area.size} bag: #{memory.size} (#{entrance.size + outlet.size + cost_area.size + memory.size})]"
    cmd = gets.chomp
    case cmd
    when 'c'
      @deck.do_candy
    when 'g'
      @deck.do_gift
    else
      case kind
      when :spread_else, :outlet_else
        num = Integer(cmd) rescue nil
        return unless num
        if (0...(@deck.hand.size)) === num
          card = @deck.hand[num]
          @deck.send(kind, card)
        end
      else
        begin
          @deck.send(kind, opt)
        rescue Deck::EmptyError
          memory.sort_by {|x| x.order}.each do |card|
            puts "* #{card.name}"
          end
          exit
        end
      end
    end
  end
end

=begin
deck = Deck.new
ui = TestUI.new(deck)
more_ui = CardUI.new(deck)

while true
  ui.prompt
  more_ui.write_to_html
end
=end
