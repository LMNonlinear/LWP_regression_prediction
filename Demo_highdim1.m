% Demo
clear;clc;

% fun = @(X) (30+(5*X(:,1)+5).*sin(5*X(:,1)+5)) .* (4+exp(-(2.5*X(:,2)+2.5).^2));
fun = @(X) (30+(5*X+5).*sin(5*X+5));
[gridX1, gridX2] = meshgrid(-1:0.2:1, -1:0.2:1);
X = [reshape(gridX1, numel(gridX1), 1) reshape(gridX2, numel(gridX2), 1)];
rng(1);
Y = fun(X) + 5 * randn(size(X));
% Y = fun(X) + 5 * randn(size(X,1), 1);

params = lwpparams('GAU', 2, false);
%fidn best h for parameters and create quary data 
[hBest, critBest, results] = lwpfindh(X, Y, params, 'CV');
params = lwpparams('GAU', 2, false, hBest);
[gridX1, gridX2] = meshgrid(-1:2/50:1, -1:2/50:1);
Xq = [reshape(gridX1, numel(gridX1), 1) reshape(gridX2, numel(gridX2), 1)];
Yq = lwppredict(X, Y, params,Xq);
Yq = reshape(Yq, size(gridX1));
%
figure;
surf(gridX1, gridX2, Yq);
axis([-1 1 -1 1 80 200]);
hold on;
plot3(X(:,1), X(:,2), Y, 'r.', 'Markersize', 20);
Ytrue = fun(Xq);
figure;
surf(gridX1, gridX2, reshape(Ytrue, size(gridX1)));
axis([-1 1 -1 1 80 200]);
%
MSE = mean((lwppredict(X, Y, params, Xq) - Ytrue) .^ 2);
MSE = lwpeval(X, Y, params, 'VD', Xq, Ytrue);
%%
figure;
hold all;
colors = get(gca, 'ColorOrder');
for i = 0 : 3
    % Global polynomial
    params = lwpparams('UNI', i, true, 1);
    [MSE, df] = lwpeval(X, Y, params, 'CV');
    plot(df, MSE, 'x', 'MarkerSize', 10, 'LineWidth', 2, 'Color', colors(i+1,:));
    % Local polynomial
    params = lwpparams('GAU', i, false);
    [hBest, critBest, results] = ...
        lwpfindh(X, Y, params, 'CV', 0:0.01:1, [], [], [], false, false);
    plot(results(:,4), results(:,2), '.-', 'MarkerSize', 10, 'Color', colors(i+1,:));
end
legend({'Global, degree = 0' 'Local, degree = 0' ...
    'Global, degree = 1' 'Local, degree = 1' ...
    'Global, degree = 2' 'Local, degree = 2' ...
    'Global, degree = 3' 'Local, degree = 3'}, 'Location', 'NorthEast');
xlabel('Degrees of freedom');
ylabel('LOOCV MSE');
