from sqlalchemy import text

# Выполняет SQL-файл: читает весь файл и отправляет запрос в БД
def run_sql_file(path, conn):
    with open(path, 'r') as f:
        sql = f.read()
    conn.execute(text(sql))

# Загружает SQL-запросы из файла и разбивает их по именам (-- name: query_name)
def load_queries(path):
    with open(path, 'r') as f:
        content = f.read()

    queries = {}
    parts = content.split('-- name:')  # делим файл на блоки по именованным запросам

    for part in parts[1:]:
        name, query = part.split('\n', 1)  # первая строка — имя, дальше сам SQL
        queries[name.strip()] = query.strip()  # сохраняем в словарь

    return queries

# Группирует страницы сайта в этапы воронки
def page_group(path):
    if path in ['/', '/index']:
        return 'landing'      # главная страница
    elif path == '/catalog':
        return 'catalog'      # каталог
    else:
        return 'car_page'     # карточка автомобиля (все остальные страницы)
