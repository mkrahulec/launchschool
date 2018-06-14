# passing_parameters_p3.rb

items = ['apples', 'corn', 'cabbage', 'wheat']

def gather(items)
  puts "Let's start gathering food."
  yield(items)
  puts "We've finished gathering!"
end

gather(items) do |*first, last|
  puts first.join(', ')
  puts last
end

puts

gather(items) do |first, *middle, last|
  puts first
  puts middle.join(', ')
  puts last
end

puts

gather(items) do |first, *last|
  puts first
  puts last.join(', ')
end

gather(items) do |first, second, third, four|
  puts "#{first}, #{second}, #{third}, and #{four}"
end