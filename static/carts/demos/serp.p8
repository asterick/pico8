pico-8 cartridge // http://www.pico-8.com
version 3
__lua__
cls()
p = {64,10,10,100,118,100}

x = p[1];
y = p[2];

pset(x,y,12)

for p1=1,128 do
cls()
p[1] = p1
for dot=1,1000 do
 i = 1 + flr(rnd(3)) * 2
 
 x = p[i]*0.5 + x*0.5
 y = p[i+1]*0.5+y*0.5
 pset(x,y,12)

end
flip()
end

