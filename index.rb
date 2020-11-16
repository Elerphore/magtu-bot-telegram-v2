require 'telegram/bot';
require 'open-uri'
require 'roo'
require 'json'
require 'mysql2'
require 'nokogiri'
require 'net/http'
require 'fileutils'


messageInlineKeyboardButtons = [
Telegram::Bot::Types::InlineKeyboardButton.new(text: "\xF0\x9F\x92\xB5 Донат", url: 'https://sobe.ru/na/elerphore'),
    ]

$messageInlineKeyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: messageInlineKeyboardButtons)

mainSiteLink = "https://newlms.magtu.ru/mod/folder/view.php?id=";
$changePageLink = "https://newlms.magtu.ru/mod/folder/view.php?id=219250";
$changeFolderContainLink = "https://newlms.magtu.ru/pluginfile.php/622284/mod_folder/content/0/";
token = ENV["TOKEN_TG"];
$branchArray = [{:number => 0, :id => 219213, :fileRoom => 622200}, {:number => 1, :id => 219208, :fileRoom => 622195},
 {:number => 2, :id => 219206, :fileRoom => 622193}, {:number => 3, :id => 219205, :fileRoom => 622192}];
groupArray = [];
yearGroupArray = Array.new(DateTime.now.strftime("%y").to_i - (DateTime.now.strftime("%y").to_i - 5)) {|i|(DateTime.now.strftime("%y").to_i - 5) + (i + 1)};
$weekArray = [{:name => "Понедельник", :number => 0}, {:name => "Понедельник", :number => 1}, {:name => "Вторник", :number => 2},
 {:name => "Среда", :number => 3}, {:name => "Четверг", :number => 4},{:name => "Пятница", :number => 5}, {:name => "Суббота", :number => 6}];



staticKeyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: 
	[["Первая подгруппа сегодня", "Вторая подгруппа сегодня"], ["Первая подгруппа завтра", "Вторая подгруппа завтра"], "Сменить группу"], one_time_keyboard: false, resize_keyboard: true);

groupJson = File.read('./groups.json');

selectBranch = [
	Telegram::Bot::Types::InlineKeyboardButton.new(text: '1 отделение', callback_data: '0,branchSelect'),
	Telegram::Bot::Types::InlineKeyboardButton.new(text: '2 отделение', callback_data: '1,branchSelect'),
	Telegram::Bot::Types::InlineKeyboardButton.new(text: '3 отделение', callback_data: '2,branchSelect'),
	Telegram::Bot::Types::InlineKeyboardButton.new(text: '4 отделение', callback_data: '3,branchSelect'),
	Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Назад', callback_data: '3,branchSelect'),
];
$inlineKeyboardSelectBranch = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: selectBranch);

$inlineKeyboardSelectYear = {};
yearSelect = []
yearGroupArray.each do |item|
	yearSelect.push(Telegram::Bot::Types::InlineKeyboardButton.new(text: "#{item} год", callback_data: "#{item},yearSelect"))
end
$inlineKeyboardSelectYear = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: yearSelect);
$removeStaticKeyboard = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true);




def databaseConnection() 
	$con = Mysql2::Client.new(:host => ENV["CLEARDB_LINK"], :username => ENV["CLEARDB_USERNAME"], :port => 3306, :database => ENV["DB_NAME"], :password => ENV["CLEARDB_KEY"]);
end

def getBranchOfGroup(branch) 
	$indeedGroupBranch = [];
	groupList = JSON.parse(File.read('./groups.json'));
	groupList.each do |item| 
		if(item["number"] == branch)
			$indeedGroupBranch.push(item);
		end
	end
	$bot.api.send_message(chat_id: $message.from.id, text: '‎‎<b>Выберите год поступления в колледж.</b>', reply_markup: $inlineKeyboardSelectYear, parse_mode: "HTML");
end

def getYearOfGroup(year) 
	inlineGroupButtons = [];
	#$inlineGroupKeyboard = {};

	$indeedGroupBranch.each do |item|
		if(item["year"] == year)
			inlineGroupButtons.push(Telegram::Bot::Types::InlineKeyboardButton.new(text: "#{item["name"]}", callback_data: "#{item["name"]},groupInput"))
		end
	end
	inlineGroupKeyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: inlineGroupButtons);
	$bot.api.send_message(chat_id: $message.from.id, text: '‎‎<b>Выберите вашу группу.</b>', reply_markup: inlineGroupKeyboard, parse_mode: "HTML");
end

def showSheduleOfCollege(subgroup, selectedDay)
	databaseConnection();
	result = $con.query("select * from users where telegram_id = #{$message.from.id}").each do |item| end
	$con.close;
	if(result[0] == nil || result[0] == [])
		$bot.api.send_message(chat_id: $message.chat.id, text: '‎‎<b>Введите группу повторно.</b>', reply_markup: $removeStaticKeyboard, parse_mode: "HTML");
		$bot.api.send_message(chat_id: $message.chat.id, text: '‎‎<b>Выберите ваше отделение.</b>', reply_markup: $inlineKeyboardSelectBranch, parse_mode: "HTML");
	else
		mysqlResult = result[0];
		isActualData(mysqlResult["user_group"]);
		parsingData(mysqlResult["user_group"], subgroup, selectedDay);
	end
end

def isActualData(groupName)
	if (!File::exists?( "#{groupName}.xlsx"))
		downloadingGroupXslx(groupName);
		return 0;
	end
	currentTime = Time.now;
	differenceTiming = (currentTime - File.ctime("./#{groupName}.xlsx"));
	if (((Time.at(differenceTiming).utc.strftime("%H").to_f) + (Time.at(differenceTiming).utc.strftime("%M").to_f) / 60) >= 6)
		File.delete("#{groupName}.xlsx");
		downloadingGroupXslx(groupName);
	end
end

def downloadingGroupXslx(name)
	$bot.api.send_message(chat_id: $message.from.id, text: "Пожалуйста, подождите.");
	JSON.parse(File.read('./groups.json')).each do |item|
		if (item["name"] == name)
			groupFileXlsx = URI.open(URI.escape("https://newlms.magtu.ru/pluginfile.php/#{$branchArray[item["number"]][:fileRoom]}/mod_folder/content/0/#{name}.xlsx"));
			IO.copy_stream(groupFileXlsx, "./#{name}.xlsx");
			break;
		end
	end
end

def parsingData(groupName, subgroup, day) 
	selectedGroup = Roo::Spreadsheet.open("#{groupName}.xlsx").sheet(0);
	selectedDay = [];
	selecteDayNumber = Date.today.wday + day;
	if (selecteDayNumber == 0)
		 selecteDayNumber = 1;
		 day += 1;
	end
	isEven = DateTime.now + day;


	selectedGroup.each_row_streaming do |row|
		row.each do |item|
			if (item.value == $weekArray[selecteDayNumber][:name]);
				selectedDay.push(item);
			end
		end
	end
	j = 1;
	lessons = [];

	dayCoordinate = selectedDay[isEven.cweek.even? ? 0 : 1].coordinate;

	while(selectedGroup.cell(dayCoordinate[0] + j, dayCoordinate[1]) != nil)
		lessonNumber = selectedGroup.cell(dayCoordinate[0] + j, dayCoordinate[1]);
		firstGroupCellName = selectedGroup.cell(dayCoordinate[0] + j, dayCoordinate[1] + 1);
		secondGroupCellName = selectedGroup.cell(dayCoordinate[0] + j, dayCoordinate[1] + 3);
		firstRoomNumber = selectedGroup.cell(dayCoordinate[0] + (j + 1), dayCoordinate[1] + 2);
		secondRoomNumber = selectedGroup.cell(dayCoordinate[0] + (j + 1), dayCoordinate[1] + 4);
		firstGroupTeacher = selectedGroup.cell(dayCoordinate[0] + (j + 1), dayCoordinate[1] + 1);
		secondGroupTeacher = selectedGroup.cell(dayCoordinate[0] + (j + 1), dayCoordinate[1] + 3);

		if (firstGroupCellName != nil && secondRoomNumber != nil && firstRoomNumber == nil)
			lessons.push({:name => firstGroupCellName, :roomNumber =>  secondRoomNumber, :number => lessonNumber, :teacher => firstGroupTeacher, :subgroup => 0});
		end
		if ((firstGroupCellName != nil && firstRoomNumber != nil) && subgroup == 1)
			lessons.push({:name => firstGroupCellName, :roomNumber =>  firstRoomNumber, :number => lessonNumber, :teacher => firstGroupTeacher, :subgroup => 1});
		end
		if ((secondGroupCellName != nil && secondRoomNumber != nil) && subgroup == 2)
			lessons.push({:name => secondGroupCellName, :roomNumber =>  secondRoomNumber, :number => lessonNumber, :teacher => secondGroupTeacher, :subgroup => 2});
		end
		j += 2;
	end
	sendingLessons = [];
	changeLessons = parsingChangeFile(groupName, subgroup, day);

	if(lessons == [] && changeLessons != [])
		sendingLessons = changeLessons;
	elsif(lessons != [] && changeLessons == [])
		sendingLessons = lessons;
	elsif(lessons == [] && changeLessons == [])
		$bot.api.send_message(chat_id: $message.from.id, text: "На данный день пар нет.", parse_mode: "HTML");
		return;
	else
		if(lessons.length <= changeLessons.length)
			lessons.map {|item| 
				changeLessons.map {|changeItem| 
					if(item[:number] == changeItem[:number])
						sendingLessons.push(changeItem);
						changeLessons.delete(changeItem);
						break;
					elsif(!lessons.detect {|e| changeLessons.map {|ech| e[:number] == ech[:number]}})
						sendingLessons.push(item);
						lessons.delete(item);
						break;
					end
				};
			};

		changeLessons.map {|item| 
			if(!sendingLessons.include?(item))
				sendingLessons.push(item);
			end
			lessons.map {|item| 
				if(!sendingLessons.include?(item) && (item[:subgroup] == 0 || item[:subgroup] == subgroup) && !sendingLessons.detect {|e| e[:number] == item[:number]})
					sendingLessons.push(item);
				end
			}
		}
	else
		lessons.map {|item| 
			changeLessons.map {|changeItem| 
				if(item[:number] == changeItem[:number])
					sendingLessons.push(changeItem);
					changeLessons.delete(changeItem);
					break;
				end
				sendingLessons.push(item);
				lessons.delete(item);
				break;
			};
		};

	lessons.map {|item| 
		if(!sendingLessons.include?(item) && (item[:subgroup] == 0 || item[:subgroup] == subgroup) && !sendingLessons.detect {|e| e[:number] == item[:number]})
			sendingLessons.push(item);
		end
	}
	end
	end

	sendingLessons = sendingLessons.sort_by {|item| item[:number]}
	stringLessons = [];
	sendingLessons.map {|item| 
		stringLessons.push("№#{item[:number]} #{item[:name].split("  ")[0]} #{item[:teacher]} #{item[:roomNumber]}")
	}

	$bot.api.send_message(chat_id: $message.from.id, text: "Расписание на <b>#{$weekArray[selecteDayNumber][:name]} (#{isEven.to_date}) <b>#{subgroup}</b> подгруппы #{groupName}  </b>\n
#{stringLessons.join("\n").gsub("  ", "")}", parse_mode: "HTML", reply_markup: $messageInlineKeyboard);
end

def parsingChangeFile(groupName, subgroup, day)
	currentDate = DateTime.now.to_date + day;
	if((currentDate).sunday?) 
		currentDate += 1;
	end
	
	selectedDateFile = [];
	groupArray = [];
	parsGroupArray = [];

	htmlDocument = Nokogiri::HTML(URI.open($changePageLink))
	htmlDocument.css('span.fp-filename-icon a').each_with_index do |link, i|
		groupArray.push(link.content.split(".xlsx"));
	end

	groupArray.each_with_index do |item, i|
		FileUtils.mkdir_p './change_lessons/';
		if(!File::exists?("./change_lessons/" + item[0] + ".xlsx"))
			downloadingFile = item[0].split(" - ")[1];
			if(downloadingFile == nil) 
				downloadingFile = item[0];
			end

			parsGroupArray[i] = Date.strptime(downloadingFile, '%d.%m.%y');
			changeFile = URI.open(URI.escape("#{$changeFolderContainLink}#{item[0]}.xlsx"));
			IO.copy_stream(changeFile, "./change_lessons/#{item[0]}.xlsx");
		end
	end
	Dir.entries("./change_lessons/").map {|item|
		if(item != '.' && item != '..')
			selectedDate = item.split(" - ")[0]
			if(selectedDate == nil) 
				selectedDate = item[0];
			end

			if(currentDate.between?(Date.strptime(selectedDate, '%d.%m.%y'), Date.strptime(selectedDate, '%d.%m.%y') + 2))
				selectedDateFile = item;
			end
		end
		};

	if(File::exists?( "./change_lessons/#{selectedDateFile}")) 
		selectedGroup = [];
		changeAgenda = Roo::Spreadsheet.open("./change_lessons/#{selectedDateFile}").sheet(0);
		
		changeAgenda.each_row_streaming do |row|
			row.each_with_index do |item, i|
				if (item.value.to_s.downcase == groupName.downcase);
					selectedGroup = item;
				end
			end
		end
		
		if(selectedGroup == [])
			return [];
		end

		j = 3;
		lessons = 0;
		dayLessons = 0;
		changeArray = [];
		parsedArray = [];
		returningArray = [];

		while changeArray == [] do
			i = 0;
			until changeAgenda.cell(j + i + lessons, 3) == nil do
				i = i + 1;
			end 
			if(changeAgenda.cell(j + lessons, 1) == $weekArray[Date.today.wday + day][:name])
				dayLessons =  i;
				for g in 0..(dayLessons)
					changeArray.push({:lesson => changeAgenda.cell(j + g + lessons, selectedGroup.coordinate[1]), :number => changeAgenda.cell(j + g + lessons, 3)});
				end
				break;
			end
			lessons +=  i + 1;
		end

		changeArray.compact.each do |item|
			if(item[:lesson] != nil)
				item[:lesson] = item[:lesson].delete("\n")
				if(subgroup == 2 && item[:lesson].split("2. ")[subgroup - 1])
					parsedArray.push({:lesson => item[:lesson].split("2. ")[1], :number => item[:number], :subgroup => 2});
				elsif(subgroup == 1 && item[:lesson].split("2. ")[0].match?(/[1][.]/))
					parsedArray.push({:lesson => item[:lesson].split("2. ")[0], :number => item[:number], :subgroup => 1});
				elsif(item[:lesson].split("2. ")[0].match?(/[1][.]/) == false && item[:lesson].split("2. ")[1] == nil)
					parsedArray.push({:lesson => item[:lesson].split("2. ")[0], :number => item[:number], :subgroup => 0});
				end
			end
		end

		parsedArray.compact.each do |item|
			if(item[:lesson] != nil)
				item[:lesson] = item[:lesson].delete("\n");
				teacher = item[:lesson].match(/[а-яА-Я]{5,10}\s[а-яА-Я]{1,3}[.]{1}[а-яА-Я]{1,2}[.]{1}/);
				name = item[:lesson].match(/[(]\W{2,8}[)]\s.{1,38}\S/).to_s.split(/\W{1}\d{3}/)[0];
				item[:lesson].match?(/[а-яА-Я]{1,3}\d{1,3}/) ? numberRoom = item[:lesson].match(/[а-яА-Я]{1,3}\d{1,3}/) : numberRoom = item[:lesson].match(/[а-яА-Я][-]{1,3}\d{1,3}/);
				if((teacher == nil && numberRoom == nil) && name)
					teacher = " ";
					numberRoom = " "
				elsif(item[:lesson].to_s.gsub(/[1-9]{1}[.]{1}\s/, "").match?(/^\D{12}\s{1,2}$/))
					name = "Пара отменена"
					teacher = " ";
					numberRoom = " "
				end
				returningArray.push({:name => name, :roomNumber => numberRoom[0], :number => item[:number], :teacher => teacher[0], :subgroup => item[:subgroup]});
			end
		end
		return returningArray;
	else
		$bot.api.send_message(chat_id: $message.from.id, text: "Боту не удалось получить доступ к файлу с заменами.", parse_mode: "HTML");
		return [];
	end
end



Telegram::Bot::Client.run(token) do |bot|
	$bot = bot;
	bot.listen do |message|
		$message = message;
		case message
			when Telegram::Bot::Types::CallbackQuery
				arrayCallBack = message.data.split(",");
				if(arrayCallBack[1] == 'groupInput') 
					databaseConnection();
					result = $con.query("select * from users where telegram_id = #{message.from.id}");
					if (result.count != 0) 
						bot.api.send_message(chat_id: message.from.id, text: '‎‎<b>Ваш ID уже зарегестрирован.</b>', reply_markup: staticKeyboard, parse_mode: "HTML");
					else
						$con.query("insert into users (telegram_id, user_group) values (#{message.from.id}, '#{arrayCallBack[0]}')");
						bot.api.send_message(chat_id: message.from.id, text: "Ваша группа успешно выбрана: <b>#{arrayCallBack[0]}.</b>", reply_markup: staticKeyboard, parse_mode: "HTML");
					end
					$con.close;
				elsif (arrayCallBack[1] == 'branchSelect') 
					getBranchOfGroup(arrayCallBack[0].to_i);
				elsif (arrayCallBack[1] == 'yearSelect') 
					getYearOfGroup(arrayCallBack[0].to_i);
				end
			when Telegram::Bot::Types::Message
				if(message.text == '/start') 
					bot.api.send_message(chat_id: message.chat.id, text: '‎‎<b>Выберите ваше отделение.</b>', reply_markup: $inlineKeyboardSelectBranch, parse_mode: "HTML");
				elsif(message.text == 'Сменить группу')
					databaseConnection();
					$con.query("delete from users where telegram_id = #{message.from.id}");
					$con.close;	
					bot.api.send_message(chat_id: message.chat.id, text: '‎‎<b>Ваша группа была удалена.</b>', reply_markup: $removeStaticKeyboard, parse_mode: "HTML");
					bot.api.send_message(chat_id: message.chat.id, text: '‎‎<b>Выберите ваше отделение.</b>', reply_markup: $inlineKeyboardSelectBranch, parse_mode: "HTML");
				elsif (message.text == 'Первая подгруппа сегодня')
					showSheduleOfCollege(1, 0);
				elsif (message.text == 'Вторая подгруппа сегодня')
					showSheduleOfCollege(2, 0);
				elsif (message.text == 'Первая подгруппа завтра')
					showSheduleOfCollege(1, 1);
				elsif (message.text == 'Вторая подгруппа завтра')
					showSheduleOfCollege(2, 1);
				end
		end
	end
end