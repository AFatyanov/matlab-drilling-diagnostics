function [conn_mask, conn_table] = detect_connections(drilling_data)
% DETECT_CONNECTIONS Идентификация соединений свечей и технологических пауз
%
% Выход:
%   conn_mask  - логический вектор [Nx1], true = идёт соединение
%   conn_table - таблица с интервалами соединений для анализа
%
% Метод: комбинированное правило на основе ROP=0, RPM=0, WOB=0,
% падения расхода и роста hookload (подъём элеватора).

data = drilling_data.data;
n = height(data);

%% Первичная маска "бурение остановлено"
% Соединение = ROP близок к нулю И нет нагрузки на долото
is_drilling = data.ROP > 0.5 & data.WOB > 1.0;
conn_mask = ~is_drilling;

%% Расширение маски: захват переходных процессов
% При соединении сначала снимается WOB, потом поднимается колонна,
% потом идёт наращивание, потом спуск. Расширяем маску в обе стороны.

% Нарастание соединения (снимается WOB, падает RPM)
for i = 2:n
    if conn_mask(i) && ~conn_mask(i-1)
        if data.RPM(i-1) < data.RPM(max(1,i-3)) * 0.5
            conn_mask(max(1,i-2):i) = true;
        end
    end
end

% Затухание соединения (восстановление параметров)
for i = 1:n-1
    if conn_mask(i) && ~conn_mask(i+1)
        if data.ROP(min(n,i+2)) < 5
            conn_mask(i:min(n,i+2)) = true;
        end
    end
end

%% Объединение в непрерывные интервалы
% Сливаем близкие соединения (разрыв < 4 точек = 1 час)
min_gap = 4;
transitions = diff([false; conn_mask; false]);
starts = find(transitions == 1);
ends = find(transitions == -1) - 1;

if isempty(starts)
    conn_table = table();
    return;
end

% Слияние близких интервалов
merged_starts = starts(1);
merged_ends = [];
for i = 2:length(starts)
    if starts(i) - ends(i-1) <= min_gap
        continue;
    else
        merged_ends(end+1) = ends(i-1);
        merged_starts(end+1) = starts(i);
    end
end
merged_ends(end+1) = ends(end);

%% Формирование таблицы соединений
n_conn = length(merged_starts);
conn_table = table();
conn_table.start_idx = merged_starts(:);
conn_table.end_idx = merged_ends(:);
conn_table.duration_points = conn_table.end_idx - conn_table.start_idx + 1;
conn_table.duration_min = conn_table.duration_points * 15;
conn_table.start_md = data.MD(merged_starts);
conn_table.start_time = drilling_data.time(merged_starts);

%% Обновление маски по итоговым интервалам
conn_mask = false(n, 1);
for i = 1:n_conn
    conn_mask(merged_starts(i):merged_ends(i)) = true;
end

fprintf('    Обнаружено соединений: %d (маска: %.1f%% времени)\n', ...
        n_conn, sum(conn_mask)/n*100);

end
