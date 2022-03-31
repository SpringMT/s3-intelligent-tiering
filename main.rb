size_tb_per_day = ARGV[0].to_f
file_count_per_day = ARGV[1].to_f
day_count = (ARGV[2] || 365).to_i

puts "#{size_tb_per_day}, #{file_count_per_day}, #{day_count}"

def calculate_standard_storage_cost(size)
  storage_cost_50_tb = 0.023 * 1000 # S3 標準と同じ
  storage_cost_50_500_tb = 0.022 * 1000 # S3標準と同じ
  storage_cost_500_tb = 0.021 * 1000 # S3 標準と同じ

  if size < 50
    size * storage_cost_50_tb
  elsif 50 <= size && size < 500
    50 * storage_cost_50_tb + ((size - 50) * storage_cost_50_500_tb)
  else
    50 * storage_cost_50_tb + 450 * storage_cost_50_500_tb + ((size - 500) * storage_cost_500_tb)
  end
end

# tieringのTBあたりのUSD
low_storage_cost_tb = 0.0125 * 1000
archive_storage_cost_tb = 0.004 * 1000

# tieringの移行するための日数
standard_to_low_day_count = 30
low_to_archive_day_count = 90

# tieringのファイル監視料金
tiering_file_watching_cost_per_file = 0.0025 / 1000

# tieringにおいて、移行するための1000件のリクエストあたり
transfer_request_cost_per_file = 0.01 / 1000

result = []
total_size = 0.0
total_file_count = 0.0

standard_storage_size = 0.0
low_storage_size = 0.0
archive_storage_size = 0.0

standard_cost = 0.0
tiering_cost = 0.0

1.upto(day_count) do |count|
  total_size += size_tb_per_day
  total_file_count += file_count_per_day
  standard_storage_size += size_tb_per_day
  standard_cost = calculate_standard_storage_cost(total_size)

  transfer_cost = 0
  if count > standard_to_low_day_count
    transfer_cost += file_count_per_day * transfer_request_cost_per_file
    standard_storage_size -= size_tb_per_day
    low_storage_size += size_tb_per_day
  end

  if count > low_to_archive_day_count
    transfer_cost += file_count_per_day * transfer_request_cost_per_file
    low_storage_size -= size_tb_per_day
    archive_storage_size += size_tb_per_day
  end

  tiering_cost = calculate_standard_storage_cost(standard_storage_size) + low_storage_size * low_storage_cost_tb + archive_storage_size * archive_storage_cost_tb
  tiering_cost += transfer_cost
  tiering_cost += total_file_count * tiering_file_watching_cost_per_file
  result << {day: count, total_size: total_size, total_file_count: total_file_count, tiering_cost: tiering_cost, standard_cost: standard_cost}
end

result.each do |r|
  puts "#{r[:day]}\t#{r[:total_size]}\t#{r[:total_file_count]}\t#{r[:tiering_cost]}\t#{r[:standard_cost]}"
end


require 'gr/plot'
tiering_cost_plot_y = result.map {|n| n[:tiering_cost] }
standard_cost_plot_y = result.map {|n| n[:standard_cost] }
day_plot_x = result.map {|n| n[:day] }
GR.plot(
  [day_plot_x, tiering_cost_plot_y], [day_plot_x, standard_cost_plot_y],
  title: "S3 standard vs tiering #{file_count_per_day} files per day and #{size_tb_per_day} TB per day at us-east-1",
  xlabel:   "day",
  ylabel:   "storage cost(USD)",
  labels:   ["tiering_cost", "standard_cost"],
)
GR.savefig("figure.jpg")

