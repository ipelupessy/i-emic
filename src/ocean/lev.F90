!! former common block file 'lev.com'
module m_lev
integer, parameter :: nlev = 33
integer, parameter :: nlev_monthly = 24
real depth(nlev)
#ifdef __PGI
data depth/0,10,20,30,50,75,100,125,150,200,250,300,400,500,600,700,800,900,1000,1100,1200,1300,1400,1500,1750,2000,2500,3000,3500,4000,4500,5000,5500/
#else
data depth(1:10)/0,10,20,30,50,75,100,125,150,200/
data depth(11:20)/250,300,400,500,600,700,800,900,1000,1100/
data depth(21:33)/1200,1300,1400,1500,1750,2000,2500,3000,3500,4000,4500,5000,5500/
#endif
end module m_lev
