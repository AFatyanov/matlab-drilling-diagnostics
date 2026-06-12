%% Загрузка результатов и построение графиков
% Этот скрипт загружает сохранённые результаты и показывает графики

fprintf('Загрузка результатов...\n');
load('../output/drilling_diagnostics_results.mat');

fprintf('Построение графиков...\n');
fig_handles = plot_diagnostics(results.drilling_data, results.features_data, results.final_events);

fprintf('Графики отображены!\n');
fprintf('Для сохранения в PNG выполните в текущей директории:\n');
fprintf('  saveas(fig_handles.timeseries, ''../output/diagnostic_timeseries.png'');\n');
fprintf('  saveas(fig_handles.risk_timeline, ''../output/risk_timeline.png'');\n');
