#!/bin/bash

# Простое нагрузочное тестирование Verb Extractor API
# Использование: ./simple_load_test.sh

set -e

API_URL="http://localhost:8080"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

echo -e "${GREEN}🧪 НАГРУЗОЧНОЕ ТЕСТИРОВАНИЕ VERB EXTRACTOR API${NC}"
echo "=============================================================="

# Проверка доступности сервера
echo -e "${YELLOW}🔍 Проверка сервера...${NC}"
if ! curl -s "$API_URL/api/health" >/dev/null 2>&1; then
    echo -e "${RED}❌ Сервер недоступен${NC}"
    echo "Запустите сервер: go run verb_extractor_server.go"
    exit 1
fi
echo -e "${GREEN}✅ Сервер доступен${NC}"

# Функция для отправки одного запроса и измерения времени
send_request() {
    local text="$1"
    local request_id="$2"

    start_time=$(date +%s%3N)
    response=$(curl -s -X POST "$API_URL/api/extract-verbs" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"$text\"}" 2>/dev/null)
    end_time=$(date +%s%3N)

    duration=$((end_time - start_time))

    # Проверка успешности
    if echo "$response" | jq -e '.verbs' >/dev/null 2>&1; then
        verb_count=$(echo "$response" | jq -r '.count' 2>/dev/null || echo "0")
        echo "$duration,$verb_count,success,$request_id"
    else
        echo "$duration,0,error,$request_id"
    fi
}

# Функция для запуска теста
run_load_test() {
    local test_name="$1"
    local text="$2"
    local num_requests="$3"

    echo -e "\n${BLUE}🚀 Тест: $test_name${NC}"
    echo "📊 Параметры: $num_requests запросов"
    echo "📝 Длина текста: ${#text} символов"
    echo "----------------------------------------"

    # Временный файл для результатов
    temp_file=$(mktemp)

    echo "Запуск запросов..."
    start_test_time=$(date +%s%3N)

    # Отправка запросов (последовательно для простоты)
    for i in $(seq 1 $num_requests); do
        send_request "$text" "$i" >> "$temp_file" &

        # Ограничиваем количество параллельных процессов
        if (( i % 10 == 0 )); then
            wait  # Ждем завершения текущей группы
            echo -n "."
        fi
    done
    wait  # Ждем завершения всех оставшихся процессов
    echo ""

    end_test_time=$(date +%s%3N)
    total_time=$((end_test_time - start_test_time))

    # Анализ результатов
    total_requests=$(wc -l < "$temp_file")
    successful_requests=$(grep -c "success" "$temp_file" || echo "0")
    failed_requests=$(grep -c "error" "$temp_file" || echo "0")

    if [ $total_requests -gt 0 ]; then
        success_rate=$(( (successful_requests * 100) / total_requests ))
        rps=$(( (total_requests * 1000) / total_time ))

        # Статистика времени отклика
        response_times=$(cut -d',' -f1 "$temp_file" | sort -n)
        min_time=$(echo "$response_times" | head -n1)
        max_time=$(echo "$response_times" | tail -n1)

        # Среднее время (примерно)
        sum_times=$(echo "$response_times" | awk '{sum += $1} END {print sum}')
        avg_time=$(( sum_times / total_requests ))

        # Медиана (примерно)
        median_line=$(( (total_requests + 1) / 2 ))
        median_time=$(echo "$response_times" | sed -n "${median_line}p")

        echo ""
        echo "📈 РЕЗУЛЬТАТЫ:"
        echo "  ⏱️  Общее время: ${total_time}ms ($(( total_time / 1000 )).$(( (total_time % 1000) / 100 ))с)"
        echo "  📊 Всего запросов: $total_requests"
        echo "  ✅ Успешных: $successful_requests ($success_rate%)"
        echo "  ❌ Неудачных: $failed_requests"
        echo "  🚀 RPS: $rps запросов/сек"
        echo ""
        echo "📊 Время отклика:"
        echo "  Среднее: ${avg_time}ms"
        echo "  Медиана: ${median_time}ms"
        echo "  Минимум: ${min_time}ms"
        echo "  Максимум: ${max_time}ms"

        # Анализ производительности
        echo ""
        echo "💡 Анализ:"
        if [ $rps -gt 50 ]; then
            echo -e "  ${GREEN}🟢 Хорошая производительность${NC}"
        elif [ $rps -gt 20 ]; then
            echo -e "  ${YELLOW}🟡 Средняя производительность${NC}"
        else
            echo -e "  ${RED}🔴 Низкая производительность${NC}"
        fi

        if [ $success_rate -ge 95 ]; then
            echo -e "  ${GREEN}🟢 Высокая надежность${NC}"
        elif [ $success_rate -ge 90 ]; then
            echo -e "  ${YELLOW}🟡 Средняя надежность${NC}"
        else
            echo -e "  ${RED}🔴 Низкая надежность${NC}"
        fi
    else
        echo -e "${RED}❌ Нет результатов для анализа${NC}"
    fi

    # Очистка
    rm -f "$temp_file"
}

# Тестовые сценарии
echo -e "${YELLOW}📋 Запуск тестовых сценариев...${NC}"

# Тест 1: Короткий текст
run_load_test "Короткий текст" \
    "Я читаю книгу и думаю о жизни" \
    50

# Пауза между тестами
echo -e "\n⏸️  Пауза 2 секунды..."
sleep 2

# Тест 2: Средний текст (ГПМРМ)
run_load_test "Средний текст (ГПМРМ)" \
    "Гарри изучал науку и читал книги. Он думал о мире и хотел понять его устройство. Профессор учил его логике и критическому мышлению. Мальчик анализировал данные и проводил эксперименты." \
    30

# Пауза между тестами
echo -e "\n⏸️  Пауза 2 секунды..."
sleep 2

# Тест 3: Длинный текст
run_load_test "Длинный текст" \
    "Студенты изучают программирование и разрабатывают проекты. Они анализируют код и исправляют ошибки. Преподаватели объясняют сложные концепции и проверяют работы. Разработчики создают приложения и тестируют функциональность. Инженеры проектируют системы и оптимизируют производительность." \
    20

# Пауза между тестами
echo -e "\n⏸️  Пауза 2 секунды..."
sleep 2

# Тест 4: Проблема из задания
run_load_test "Проблема из задания (разные формы глагола)" \
    "Он ударил мяч. Нужно ударить точно. Я ударяю по цели. Все ударили по мишени." \
    40

# Финальный быстрый тест
echo -e "\n${YELLOW}⚡ БЫСТРЫЙ СТРЕСС-ТЕСТ${NC}"
echo "Отправка 100 быстрых запросов..."

stress_start=$(date +%s%3N)
success_count=0
for i in {1..100}; do
    if curl -s -X POST "$API_URL/api/extract-verbs" \
        -H "Content-Type: application/json" \
        -d '{"text":"быстрый тест"}' | jq -e '.verbs' >/dev/null 2>&1; then
        ((success_count++))
    fi

    if (( i % 20 == 0 )); then
        echo -n "."
    fi
done
echo ""
stress_end=$(date +%s%3N)
stress_duration=$((stress_end - stress_start))
stress_rps=$(( (100 * 1000) / stress_duration ))

echo "⚡ Стресс-тест результаты:"
echo "  Время: ${stress_duration}ms"
echo "  Успешных: $success_count/100"
echo "  RPS: $stress_rps запросов/сек"

# Итоговая информация
echo ""
echo "=============================================================="
echo -e "${GREEN}🎉 НАГРУЗОЧНОЕ ТЕСТИРОВАНИЕ ЗАВЕРШЕНО${NC}"
echo "=============================================================="

echo ""
echo "💡 Рекомендации по оптимизации:"
echo "   • Добавить кэширование результатов лемматизации"
echo "   • Использовать connection pooling"
echo "   • Оптимизировать регулярные выражения"
echo "   • Добавить индексы в словарь глаголов"
echo "   • Использовать горутины для параллельной обработки"

echo ""
echo "🔗 Полезные ссылки:"
echo "   • Документация API: $API_URL/"
echo "   • Health check: $API_URL/api/health"
echo "   • Метрики: $API_URL/api/metrics"
