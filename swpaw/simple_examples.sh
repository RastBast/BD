#!/bin/bash

# Простые примеры использования Verb Extractor API
# Использование: ./simple_examples.sh

set -e

API_URL="http://localhost:8080"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

echo -e "${GREEN}🚀 ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ VERB EXTRACTOR API${NC}"
echo "=========================================================="

# Проверка доступности сервера
echo -e "\n${YELLOW}🔍 Проверка сервера...${NC}"
if curl -s "$API_URL/api/health" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Сервер доступен${NC}"
    health_info=$(curl -s "$API_URL/api/health" | jq -r '.status + " (версия: " + .version + ")"' 2>/dev/null || echo "ok")
    echo "Статус: $health_info"
else
    echo -e "${RED}❌ Сервер недоступен${NC}"
    echo "Запустите сервер: go run verb_extractor_server.go"
    exit 1
fi

# Функция для отправки запроса
test_text() {
    local description="$1"
    local text="$2"

    echo -e "\n${BLUE}📝 $description${NC}"
    echo "Текст: "$text""

    # Отправка запроса
    response=$(curl -s -X POST "$API_URL/api/extract-verbs" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"$text\"}")

    # Проверка на ошибки
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        echo -e "${RED}❌ Ошибка API:${NC}"
        echo "$response" | jq -r '.message' 2>/dev/null || echo "$response"
        return
    fi

    # Извлечение результатов
    verb_count=$(echo "$response" | jq -r '.count' 2>/dev/null || echo "0")
    processing_time=$(echo "$response" | jq -r '.time' 2>/dev/null || echo "unknown")
    verbs=$(echo "$response" | jq -r '.verbs | join(", ")' 2>/dev/null || echo "нет данных")

    echo -e "${GREEN}✅ Найдено глаголов: $verb_count${NC}"
    if [ "$verb_count" -gt 0 ]; then
        echo "📋 Глаголы: $verbs"
    fi
    echo "⏱️  Время обработки: $processing_time"
}

# Базовые примеры
echo -e "\n${YELLOW}🧪 БАЗОВЫЕ ПРИМЕРЫ${NC}"
echo "----------------------------------------"

test_text "Простой пример" "Я читаю книгу и думаю о жизни"

test_text "Разные времена" "Вчера я читал, сегодня читаю, завтра буду читать"

test_text "Возвратные глаголы" "Дети учатся в школе и развиваются быстро"

test_text "Глаголы движения" "Студент идет в университет, бежит на лекцию, едет домой"

# Сложные случаи
echo -e "\n${YELLOW}🧪 СЛОЖНЫЕ СЛУЧАИ${NC}"
echo "----------------------------------------"

test_text "Проблема из задания (ударил/ударить/ударяю)" \
    "Он ударил мяч. Нужно ударить точно. Я ударяю по цели. Все ударили по мишени."

test_text "Глаголы с приставками" \
    "Переписать код, дописать функцию, записать результат, списать с доски"

test_text "Модальные глаголы" \
    "Я должен работать, могу помочь, хочу учиться, буду стараться"

# Примеры из ГПМРМ
echo -e "\n${YELLOW}🧪 ПРИМЕРЫ ИЗ ГАРРИ ПОТТЕРА И МЕТОДОВ РАЦИОНАЛЬНОГО МЫШЛЕНИЯ${NC}"
echo "----------------------------------------------------------------"

test_text "Фрагмент о образовании Гарри" \
    "Гарри изучал науку и читал книги. Он думал о мире и хотел понять его устройство. Профессор учил его логике и критическому мышлению."

test_text "Фрагмент о научном методе" \
    "Мальчик анализировал данные и проводил эксперименты. Студенты слушали лекции и записывали важные моменты."

test_text "Фрагмент о исследованиях" \
    "Исследователи изучают новые явления и публикуют свои открытия. Ученые работают над важными проектами."

# Технические тексты
echo -e "\n${YELLOW}🧪 ТЕХНИЧЕСКИЕ ТЕКСТЫ${NC}"
echo "----------------------------------------"

test_text "Программирование" \
    "Разработчик пишет код, тестирует функции, исправляет ошибки и деплоит приложение."

test_text "Наука и технологии" \
    "Инженеры создают новые технологии, исследуют материалы, моделируют процессы."

test_text "Образование" \
    "Преподаватели объясняют концепции, проверяют знания, разрабатывают курсы."

# Тест производительности
echo -e "\n${YELLOW}📊 ТЕСТ ПРОИЗВОДИТЕЛЬНОСТИ${NC}"
echo "----------------------------------------"

echo -e "${BLUE}Тестирование скорости обработки...${NC}"

# Короткий текст - 5 запросов
echo "Короткий текст (5 запросов):"
for i in {1..5}; do
    start_time=$(date +%s%3N)
    response=$(curl -s -X POST "$API_URL/api/extract-verbs" \
        -H "Content-Type: application/json" \
        -d '{"text":"Я читаю и пишу код"}')
    end_time=$(date +%s%3N)
    duration=$((end_time - start_time))

    verb_count=$(echo "$response" | jq -r '.count' 2>/dev/null || echo "0")
    echo "  Запрос $i: ${duration}ms, глаголов: $verb_count"
done

# Получение метрик сервера
echo -e "\n${YELLOW}📈 МЕТРИКИ СЕРВЕРА${NC}"
echo "----------------------------------------"

metrics=$(curl -s "$API_URL/api/metrics")
if [ $? -eq 0 ]; then
    echo "📊 Метрики сервера:"
    echo "$metrics" | jq . 2>/dev/null || echo "$metrics"
else
    echo "⚠️  Не удалось получить метрики"
fi

# Итоговая информация
echo -e "\n${GREEN}🎉 ВСЕ ПРИМЕРЫ ВЫПОЛНЕНЫ${NC}"
echo "=========================================================="

echo -e "\n💡 Полезные команды:"
echo "  • Запуск сервера: go run verb_extractor_server.go"
echo "  • Документация: http://localhost:8080/"
echo "  • Health check: curl $API_URL/api/health"
echo "  • Ручной тест: curl -X POST $API_URL/api/extract-verbs -H 'Content-Type: application/json' -d '{"text":"ваш текст"}'"

echo -e "\n📚 Дополнительные скрипты:"
echo "  • ./simple_load_test.sh - нагрузочное тестирование"
echo "  • ./test_api.sh - полное тестирование API"
