function [Yq, L] = weightAndPredict(Xtr, Ytr, params, Xq, wObs, failSilently, XqIsXtr)
[n, d] = size(Xtr);
nq = size(Xq, 1);
L = NaN;
needL = nargout > 1;

params.degree = max(0, params.degree);
if abs(params.degree - floor(params.degree + eps)) < eps
    params.degree = floor(params.degree + eps);
    r = exponents(d, params.degree);
    rCoef = NaN;
    rDegree = NaN;
else
    degreeInt = floor(params.degree + eps);
    rCoef = params.degree - degreeInt;
    params.degree = degreeInt + 1;
    r = exponents(d, params.degree);
    rDegree = sum(r, 2);
end
nTerms = size(r, 1);

if params.useKNN
    if ~isUsableWithKNN(params.kernel)
        error('Cannot use the kernel with nearest neighbor window.');
    end
    if params.h <= 1 % fraction of the whole data
        params.h = min(n, floor(n * (params.h + eps)));
    else
        params.h = min(n, floor(params.h + eps));
    end
    if params.h < 1
        if failSilently
            Yq = NaN;
            return;
        else
            error('Neighborhood size should be at least 1.');
        end
    end
    if params.safe
        if isUniform(params.kernel)
            if params.h < nTerms
                if failSilently
                    Yq = NaN;
                    return;
                else
                    error(['If params.safe = true then, for this kernel, neighborhood size should be larger than or equal to the number of terms in the polynomial (i.e., at least ' num2str(nTerms) ').']);
                end
            end
        else
            if params.h < nTerms + 1 % "+1" is because the weight for the farthest neighbor will be set to 0
                if failSilently
                    Yq = NaN;
                    return;
                else
                    error(['If params.safe = true then, for this kernel, neighborhood size should be larger than the number of terms in the polynomial (i.e., at least ' num2str(nTerms) ' + 1).']);
                end
            end
        end
    else
        if ((params.h <= 2) && (params.degree > 0) && (~isUniform(params.kernel))) || ...
           ((params.h == 1) && (params.degree > 0) && isUniform(params.kernel))
            % Because that means that there will be one observation for the
            % actual prediction and that is not enough even for the "unsafe"
            % calculations.
            if failSilently
                Yq = NaN;
                return;
            else
                error('Neighborhood size too small.');
            end
        end
    end
    
    % Calculate weights
    if isUniform(params.kernel)
        if isempty(wObs)
            [knnIdx, w] = knnU(Xtr, Xq, params.h, false);
        else
            [knnIdx, w] = knnUW(Xtr, Xq, params.h, wObs, params.knnSumWeights, false);
        end
    else
        if isempty(wObs)
            [knnIdx, u] = knnU(Xtr, Xq, params.h, true);
        else
            [knnIdx, u] = knnUW(Xtr, Xq, params.h, wObs, params.knnSumWeights, true);
        end
        switch upper(params.kernel)
            case 'TRI'
                w = kernelTriangular(u);
            case 'EPA'
                w = kernelEpanechnikov(u);
            case 'BIW'
                w = kernelBiweight(u);
            case 'TRW'
                w = kernelTriweight(u);
            case 'TRC'
                w = kernelTricube(u);
            case 'COS'
                w = kernelCosine(u);
        end
    end
    
    % Apply observation weights
    if ~isempty(wObs)
        for i = 1 : nq
            w(:,i) = w(:,i) .* wObs(knnIdx(:,i));
        end
    end
    
    origWarningState = warning;
    if exist('OCTAVE_VERSION', 'builtin')
        warning('off', 'Octave:nearly-singular-matrix');
        warning('off', 'Octave:singular-matrix');
    else
        warning('off', 'MATLAB:nearlySingularMatrix');
        warning('off', 'MATLAB:singularMatrix');
    end
    
    if needL
        [Yq, L] = predict(Xtr, Ytr, Xq, w, nTerms, knnIdx, params, failSilently, r, rDegree, rCoef, XqIsXtr);
    else
        Yq = predict(Xtr, Ytr, Xq, w, nTerms, knnIdx, params, failSilently, r, rDegree, rCoef, XqIsXtr);
    end
    
    warning(origWarningState);
    return;
end

%---------------------------------------------

if isHCanBeZero(params.kernel)
    if (params.h < 0)
        if failSilently
            Yq = NaN;
            return;
        else
            error('params.h for this kernel should be larger than or equal to 0.');
        end
    end
else
    if (params.h <= 0)
        if failSilently
            Yq = NaN;
            return;
        else
            error('params.h for this kernel should be larger than 0.');
        end
    end
end

if isMultiplyHByMaxDist(params.kernel)
    params.h = params.h * norm(max(Xtr) - min(Xtr)); % distance between two opposite corners of the hypercube
end

% Calculate distances
dist = zeros(n, nq);
for i = 1 : nq
    dist(:,i) = sum((repmat(Xq(i, :), n, 1) - Xtr) .^ 2, 2);
end
if ~isempty(params.outer)
dis_asc=sort(dist,'ascend');
params.h=sqrt(dis_asc(10,:));
else
  params.h=params.h;
end
% Calculate weights
switch upper(params.kernel)
    case 'UNI'
        w = kernelUniform(sqrt(dist) / params.h);
    case 'TRI'
        w = kernelTriangular(sqrt(dist) / params.h);
    case 'EPA'
        w = kernelEpanechnikov(sqrt(dist) ./ params.h);
    case 'BIW'
        w = kernelBiweight(sqrt(dist) / params.h);
    case 'TRW'
        w = kernelTriweight(sqrt(dist) / params.h);
    case 'TRC'
        w = kernelTricube(sqrt(dist) / params.h);
    case 'COS'
        w = kernelCosine(sqrt(dist) / params.h);
    case 'GAU'
        w = kernelGaussian(dist, params.h);
    case 'GAR'
        w = kernelGaussianRikards(dist, params.h);
end

% Apply observation weights
if ~isempty(wObs)
    w = w .* repmat(wObs, 1, nq);
end

origWarningState = warning;
if exist('OCTAVE_VERSION', 'builtin')
    warning('off', 'Octave:nearly-singular-matrix');
    warning('off', 'Octave:singular-matrix');
else
    warning('off', 'MATLAB:nearlySingularMatrix');
    warning('off', 'MATLAB:singularMatrix');
end

if needL
    [Yq, L] = predict(Xtr, Ytr, Xq, w, nTerms, [], params, failSilently, r, rDegree, rCoef, XqIsXtr);
else
    Yq = predict(Xtr, Ytr, Xq, w, nTerms, [], params, failSilently, r, rDegree, rCoef, XqIsXtr);
end

warning(origWarningState);
return