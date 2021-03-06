clear all
JnC = load_numjac('JnC');

%vsm(JnC)

[n m l la nun xmin xmax ymin ymax hdim x y z xu yv zw landm] = ...
    readfort44('fort.44');

dfo = 6; dfa = 3; auxa = 1; dfs = 4; auxs = 1

surfb = find_row(dfo, n, m ,l, 1, 1, l, 1);
surfe = find_row(dfo, n, m ,l, n, m, l, dfo);

nocean  = n*m*l*dfo;
natmos  = n*m*dfa;
nseaice = n*m*dfs;

ndim = nocean + natmos + auxa + nseaice + auxs;

fr0 = @(dof,i,j,k,xx) k * n * m * dof + j * n * dof + i * dof + xx;

atm_idx = [];
oce_idx = [];
sei_idx = [];

% normal ordering
for i = 1:dfo
    oce_idx = [oce_idx, (i:dfo:nocean)];
end

% special ordering
uv_idx = [(1:dfo:nocean); (2:dfo:nocean)];
uv_idx = uv_idx(:);
w_idx  = (3:dfo:nocean)';
p_idx  = (4:dfo:nocean)';
TS_idx = [(5:dfo:nocean); (6:dfo:nocean)];
TS_idx = TS_idx(:);

oce_idx = [uv_idx ; w_idx ; p_idx ; TS_idx]';

%oce_idx = sort(oce_idx);

% normal ordering
for i = 1:dfa
    atm_idx = [atm_idx, (nocean+i:dfa:nocean+natmos)];
end

% special ordering
Tq_idx  = [(nocean+1:dfa:nocean+natmos); (nocean+2:dfa:nocean+natmos)];
Tq_idx  = Tq_idx(:);
al_idx  = (nocean+3:dfa:nocean+natmos)';
atm_idx = [Tq_idx ; al_idx ;]'; 

atm_idx = [atm_idx, nocean+natmos+auxa];

%atm_idx = sort(atm_idx);

% normal ordering
for i = 1:dfs
    sei_idx = [sei_idx, (nocean+natmos+auxa+i:dfs:nocean+natmos+auxa+nseaice)];
end

% special ordering
HQT_idx = [(nocean+natmos+auxa+1:dfs:nocean+natmos+auxa+nseaice);
           (nocean+natmos+auxa+2:dfs:nocean+natmos+auxa+nseaice);
           (nocean+natmos+auxa+4:dfs:nocean+natmos+auxa+nseaice)];
HQT_idx = HQT_idx(:);
Msi_idx = (nocean+natmos+auxa+3:dfs:nocean+natmos+auxa+nseaice)';
sei_idx = [HQT_idx ; Msi_idx]';

sei_idx = [sei_idx, nocean+natmos+auxa+nseaice+auxs];

%sei_idx = sort(sei_idx);

JnC11 = JnC(oce_idx, oce_idx);
JnC22 = JnC(atm_idx, atm_idx);
JnC33 = JnC(sei_idx, sei_idx);

JnC12 = JnC(oce_idx, atm_idx);
JnC13 = JnC(oce_idx, sei_idx);

JnC21 = JnC(atm_idx, oce_idx);
JnC23 = JnC(atm_idx, sei_idx);

JnC31 = JnC(sei_idx, oce_idx);
JnC32 = JnC(sei_idx, atm_idx);

tot_idx = [oce_idx, atm_idx, sei_idx];
JnC_ = JnC;
JnC  = JnC(tot_idx, tot_idx);

% plot numerical jacobian
gridcol=[.3,.6,.8];
spy(JnC, 'k', 5); hold on;
xuv = numel(uv_idx) + .5;
xw  = numel(w_idx)  + xuv;
xp  = numel(p_idx)  + xw;
xTS = numel(TS_idx) + xp;
xTq = numel(Tq_idx) + xTS;
xal = numel(al_idx) + xTq;
xP  = xTq + 1;
xHQT= numel(HQT_idx) + xP;
xMsi= numel(Msi_idx) + xHQT;
xgamma = xMsi + 1;
for xcoord = [xuv, xw, xp, xTS, xTq, xal, xP, xHQT, xMsi, xgamma]
    plot([xcoord,xcoord],ylim,'color',gridcol);
    plot(xlim, [xcoord,xcoord],'color',gridcol);
end
xlabel('');
ylabel('');
xticks('');
yticks('');
% remove offsets of ranges
oce_idx = oce_idx - 0;
atm_idx = atm_idx - nocean;
sei_idx = sei_idx - nocean - natmos - auxa;

C11 = load('J_Ocean');              C11 = spconvert(C11);
C12 = load('C_Ocean-Atmosphere');   C12 = spconvert(C12);
C12 = padding(C12, nocean, natmos + auxa);
C13 = load('C_Ocean-SeaIce');       C13 = spconvert(C13);
C13 = padding(C13, nocean, nseaice + auxs);

C21 = load('C_Atmosphere-Ocean');   C21 = spconvert(C21);
C21 = padding(C21, natmos + auxa, nocean);
C22 = load('J_Atmosphere');         C22 = spconvert(C22);
C23 = load('C_Atmosphere-SeaIce');  C23 = spconvert(C23);
C23 = padding(C23, natmos + auxa, nseaice + auxs);

C31 = load('C_SeaIce-Ocean');       C31 = spconvert(C31);
C31 = padding(C31, nseaice + auxs, nocean);
    
C32 = load('C_SeaIce-Atmosphere');  C32 = spconvert(C32);
C32 = padding(C32, nseaice + auxs, natmos + auxa);

C33 = load('J_SeaIce');             C33 = spconvert(C33);

% block might be smaller
tr12 = size(C12,1);
tr32 = size(C32,2);

C_ = [C11, C12, C13; C21, C22, C23; C31, C32, C33];

C  = C_(tot_idx, tot_idx);

C11 = C11(oce_idx, oce_idx);
C12 = C12(oce_idx, atm_idx); 
C13 = C13(oce_idx, sei_idx);

C21 = C21(atm_idx, oce_idx);
C22 = C22(atm_idx, atm_idx);
C23 = C23(atm_idx, sei_idx);

C31 = C31(sei_idx, oce_idx);
C32 = C32(sei_idx, atm_idx);
C33 = C33(sei_idx, sei_idx);

