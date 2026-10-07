# Construit le décor officiel de Valdrune (carte 1) à partir du plan validé, sur le vrai relief.
import json, math, random
random.seed(11)
d=json.load(open('/tmp/claude-0/v88/terrain.json'))
N=d['N']; H=d['h']; WK=d['walk']; CK=d['cliff']
LAKE=((-46,8),10.0)
def idx(x,z):
    i=int(round((x+128)/2)); j=int(round((z+128)/2))
    if 0<=i<N and 0<=j<N: return j*N+i
    return None
def hgt(x,z):
    k=idx(x,z); return H[k] if k is not None else 99
def walk(x,z):
    k=idx(x,z)
    if k is None or WK[k]!=1 or CK[k]>0.45: return False
    if math.hypot(x-LAKE[0][0],z-LAKE[0][1])<LAKE[1]+3: return False
    return abs(x)<106 and abs(z)<106
objs=[]; occ=[]; roads=[]
def put(path,x,z,rot=0.0,solid=True,sc=1.0):
    p=path[len('res://assets/'):] if path.startswith('res://assets/') else path
    objs.append([p,round(x,2),round(z,2),round(rot,3),sc,0.0,1 if solid else 0])
def face(x,z,tx,tz): return math.atan2(tx-x,tz-z)
def segd(p,a,b):
    ax,az=a; bx,bz=b; px,pz=p
    vx,vz=bx-ax,bz-az; L2=vx*vx+vz*vz or 1e-6
    t=max(0,min(1,((px-ax)*vx+(pz-az)*vz)/L2)); return math.hypot(px-ax-vx*t,pz-az-vz*t)
def road_dist(x,z):
    best=1e9
    for pl,w in roads:
        for i in range(len(pl)-1): best=min(best,segd((x,z),pl[i],pl[i+1])-w/2)
    return best
def free(x,z,r):
    for (ox,oz,orr) in occ:
        if math.hypot(x-ox,z-oz)<r+orr: return False
    return True
def spline(pts,step=1.5):
    out=[]; p=[pts[0]]+pts+[pts[-1]]
    for k in range(1,len(p)-2):
        a,b,c,e=p[k-1],p[k],p[k+1],p[k+2]
        L=math.hypot(c[0]-b[0],c[1]-b[1]); n=max(2,int(L/step))
        for i in range(n):
            t=i/n; t2,t3=t*t,t*t*t
            out.append(tuple(0.5*((2*b[q])+(-a[q]+c[q])*t+(2*a[q]-5*b[q]+4*c[q]-e[q])*t2+(-a[q]+3*b[q]-3*c[q]+e[q])*t3) for q in range(2)))
    out.append(pts[-1]); return out
def add_road(pts,w,kind='pave',smooth=True):
    pl=spline(pts) if smooth else pts
    roads.append((pl,w))
    cx=sum(p[0] for p in pl)/len(pl); cz=sum(p[1] for p in pl)/len(pl)
    enc=';'.join('%s,%s'%(round(p[0]-cx,1),round(p[1]-cz,1)) for p in pl)
    put('@road:%s:%s:%s'%(kind,w,enc),cx,cz,0.0,False)
def house_ok(x,z,rot,w=6.4,dd=8.4,margin=0.8):
    ca,sa=math.cos(rot),math.sin(rot)
    hs=[]
    for u,v in [(-w/2,-dd/2),(w/2,-dd/2),(w/2,dd/2),(-w/2,dd/2),(0,0),(0,dd/2),(0,-dd/2)]:
        # local (u,v) -> monde : Basis(UP, rot) * (u,0,v)
        wx=x+u*ca+v*sa; wz=z-u*sa+v*ca
        if not walk(wx,wz) or road_dist(wx,wz)<margin: return False
        hs.append(hgt(wx,wz))
    if max(hs)-min(hs)>2.4: return False
    return free(x,z,max(w,dd)/2-0.4)
def building(path,x,z,rot,w=6.4,dd=8.4,force=False):
    if not force and not house_ok(x,z,rot,w,dd): return False
    put(path,x,z,rot,True); occ.append((x,z,max(w,dd)/2-0.2)); return True
def front(x,z,rot,dist): return (x+math.sin(rot)*dist, z+math.cos(rot)*dist)
def npc(key,x,z,rot):
    put('@npc:'+key,x,z,rot,False); occ.append((x,z,0.8))
HOUSES=['@house:6:2:plaster','@house:6:2:brick','@house:6:3:brick','@house:6:3:plaster','@house:6:1:plaster','@house:6:2:plaster']
SMALL=['@house:6:1:plaster','@house:4:2:plaster','@house:4:1:plaster','@house:6:2:plaster']
# ================= LA VILLE =================
C=(0.0,62.0); PR=14.0
put('@plaza:14',C[0],C[1],0.0,False); occ.append((C[0],C[1],PR))
put('@fountain',C[0],C[1],0.0,True)
AV={'N':(0,-1),'E':(1,0),'W':(-1,0),'S':(0,1)}
AVE_W=6.0; RING=31.0
ends={}
for k,(dx,dz) in AV.items():
    L=44 if k in 'NEW' else 34
    a=(C[0]+dx*(PR-1),C[1]+dz*(PR-1)); b=(C[0]+dx*L,C[1]+dz*L)
    add_road([a,b],AVE_W,'pave',smooth=True); ends[k]=b
# boulevard circulaire
ring=[(C[0]+math.cos(t/48*math.tau)*RING,C[1]+math.sin(t/48*math.tau)*RING) for t in range(49)]
ring=[p for p in ring]
add_road(ring,4.5,'pave',smooth=False)
avdir=[math.atan2(dz,dx) for dx,dz in AV.values()]
def ang_ok(a,r,half):
    for ad in avdir:
        dd=abs((a-ad+math.pi)%math.tau-math.pi)
        if dd*r<half: return False
    return True
# bâtiments face à la place (services)
plaza_slots=[]
r=PR+2.6+4.2
for q in range(4):
    base=math.pi/4+q*math.pi/2
    for off in (-0.36,0.0,0.36):
        a=base+off
        if ang_ok(a,r,AVE_W/2+3.6): plaza_slots.append(a)
services=[('@shop:blue','shop',6.1),('HOUSE',None,0),('@shop:purple','auction',6.1),('@forge','forge',3.2),('HOUSE',None,0),('@shop:green','mercs',6.1),('@shop:red','tannery',6.1),('HOUSE',None,0),('@forge','sawmill',3.2),('HOUSE',None,0),('@shop:blue',None,0),('HOUSE',None,0)]
for a,(bp,key,fd) in zip(plaza_slots,services):
    x=C[0]+math.cos(a)*r; z=C[1]+math.sin(a)*r; rot=face(x,z,*C)
    w,dd=(5.6,4.4) if bp=='@forge' else (6.4,8.4)
    if bp=='HOUSE': bp=random.choice(HOUSES)
    if building(bp,x,z,rot,w,dd,force=True) and key:
        fx,fz=front(x,z,rot,fd); npc(key,fx,fz,rot)
# maisons à l'extérieur du boulevard, face au centre
n_out=0
for rr in (RING+2.25+1.0+4.2,):
    a=0.0; step=8.4/rr
    while a<math.tau:
        if ang_ok(a,rr,AVE_W/2+4.0):
            x=C[0]+math.cos(a)*rr; z=C[1]+math.sin(a)*rr
            if building(random.choice(HOUSES if rr<45 else SMALL),x,z,face(x,z,*C)): n_out+=1
        a+=step
# le long des avenues, après le boulevard : maisons alignées face à l'avenue
for k,(dx,dz) in AV.items():
    L=44 if k in 'NEW' else 34
    s_=RING+2.25+4.0
    while s_<L-1:
        for side in (-1,1):
            nx,nz=-dz*side,dx*side
            x=C[0]+dx*s_+nx*(AVE_W/2+1.6+4.2); z=C[1]+dz*s_+nz*(AVE_W/2+1.6+4.2)
            building(random.choice(HOUSES),x,z,math.atan2(-nx,-nz))
        s_+=7.2
# marché : étals des vendeurs d'outils sur la place
for i,key in enumerate(['tools:hache','tools:pioche','tools:faucille']):
    a=math.radians(200+i*55); x=C[0]+math.cos(a)*9.5; z=C[1]+math.sin(a)*9.5; rot=face(x,z,*C)
    sx,sz=front(x,z,rot,-1.8); put('@stall',sx,sz,rot,True)
    npc(key,x,z,rot)
# l'Ancien près de la fontaine, bancs, lanternes
npc('quest',C[0]+3.4,C[1]+3.4,face(C[0]+3.4,C[1]+3.4,*C)+math.pi)
for a in (math.radians(20),math.radians(160),math.radians(-20),math.radians(-160)):
    x=C[0]+math.cos(a)*5.2; z=C[1]+math.sin(a)*5.2; put('@bench',x,z,face(x,z,*C),True)
LANT='res://assets/halloween/lantern_standing.gltf'
for k,(dx,dz) in AV.items():
    L=44 if k in 'NEW' else 34
    s=PR+4
    while s<L-2:
        for side in (-1,1):
            x=C[0]+dx*s+(-dz)*side*(AVE_W/2+0.7); z=C[1]+dz*s+dx*side*(AVE_W/2+0.7)
            if walk(x,z): put(LANT,x,z,0.0,True)
        s+=10
for t in range(0,48,6):
    a=t/48*math.tau+0.07; x=C[0]+math.cos(a)*(RING-2.9); z=C[1]+math.sin(a)*(RING-2.9)
    if walk(x,z) and ang_ok(a,RING,AVE_W/2+2): put(LANT,x,z,0.0,True)
# gardes aux portes, passeur, villageois
for k in 'NEWS':
    ex,ez=ends[k]; dx,dz=AV[k]
    npc('guard',ex+(-dz)*(AVE_W/2+1.2),ez+dx*(AVE_W/2+1.2),math.atan2(dx,dz))
ex,ez=ends['N']; npc('travel',ex+(AVE_W/2+1.4),ez+3,math.pi)
put('@well',C[0]-22,C[1]-22,0.0,True)
for i in range(8):
    k=random.choice('NEWS'); dx,dz=AV[k]; s=random.uniform(PR+3,40); side=random.choice((-1,1))
    x=C[0]+dx*s+(-dz)*side*(AVE_W/2+0.6); z=C[1]+dz*s+dx*side*(AVE_W/2+0.6)
    if walk(x,z): npc('talk',x,z,random.random()*math.tau)
# ================= ROUTES DU VAL =================
add_road([ends['N'],(-8,10),(-14,-4),(-6,-30),(10,-58),(6,-84),(0,-101)],4.0,'dirt')
add_road([ends['E'],(56,56),(60,44),(66,22),(74,2)],3.6,'dirt')
add_road([ends['W'],(-50,56),(-42,40),(-40,24)],3.6,'dirt')
add_road([ends['S'],(-8,100),(-30,104)],3.4,'dirt')
add_road([(-6,-30),(-24,-36),(-46,-40)],3.2,'dirt')
# ================= HAMEAUX, CHAMPS, LIEUX =================
def hamlet(cx,cz,n,a0):
    put('@plaza:6',cx,cz,0.0,False); occ.append((cx,cz,6))
    put('@well',cx,cz,0.0,True)
    for k in range(n):
        a=a0+k*math.tau/n; x=cx+math.cos(a)*12; z=cz+math.sin(a)*12
        building(random.choice(SMALL),x,z,face(x,z,cx,cz))
    npc('talk',cx+3,cz+2,0.0)
hamlet(64,40,4,0.4)
hamlet(-46,40,3,1.2)
put('res://assets/hex/building_windmill_blue.gltf',76,52,-0.6,True,3.0); occ.append((76,52,4))
def field_ok(cx,cz,w,hh):
    cs=[(cx+u,cz+v) for u in (-w/2,0,w/2) for v in (-hh/2,0,hh/2)]
    return all(walk(*c) and road_dist(*c)>1.0 for c in cs) and free(cx,cz,max(w,hh)/2+1.5) and max(hgt(*c) for c in cs)-min(hgt(*c) for c in cs)<2.6
def field(tx,tz,w,hh,rot,crop):
    for tries in range(300):
        rr=tries*0.1; a=random.random()*math.tau
        cx=tx+math.cos(a)*rr; cz=tz+math.sin(a)*rr
        if field_ok(cx,cz,w,hh):
            put('@field:%s:%d:%d'%(crop,w,hh),cx,cz,rot,False); occ.append((cx,cz,max(w,hh)/2)); return True
    return False
nf=0
for f in [(-30,92,12,9,0.1,'wheat'),(-46,80,10,10,-0.2,'cabbage'),(36,92,12,9,-0.1,'wheat'),(50,78,10,9,0.2,'carrot'),(52,24,10,9,0.3,'wheat'),(-60,50,10,8,0.0,'wheat'),(-60,30,9,9,0.2,'cabbage'),(76,64,10,8,0.1,'wheat')]:
    nf+=field(*f)
print('fields',nf)
def spot(tx,tz,r,flat=1.6,mind=0):
    for tries in range(600):
        rr=tries*0.08; a=random.random()*math.tau
        x=tx+math.cos(a)*rr; z=tz+math.sin(a)*rr
        if math.hypot(x-C[0],z-C[1])<mind: continue
        cs=[(x+math.cos(b)*r,z+math.sin(b)*r) for b in [i*math.tau/8 for i in range(8)]]+[(x,z)]
        if all(walk(*c) for c in cs) and free(x,z,r) and road_dist(x,z)>r+0.5 and max(hgt(*c) for c in cs)-min(hgt(*c) for c in cs)<flat: return x,z
    return tx,tz
mx_,mz_=spot(80,8,5,2.5); put('res://assets/hex/building_mine_blue.gltf',mx_,mz_,-1.2,True,3.0); occ.append((mx_,mz_,5))
put('@tower',86,-22,0.0,True); occ.append((86,-22,3))
for k in range(6):
    a=k/6*math.tau; put('res://assets/dungeon/pillar_decorated.gltf',-34+math.cos(a)*4,-66+math.sin(a)*4,a,True)
put('res://assets/crystal/PROP_09_FloatingMagicCrystal.glb',-34,-66,0.0,True); occ.append((-34,-66,6))
ax_,az_=spot(-24,10,10.5,1.4,58)
put('@plaza:8',ax_,az_,0.0,False); occ.append((ax_,az_,10.5))
for k in range(10):
    a=k/10*math.tau; put('res://assets/dungeon/pillar.gltf',ax_+math.cos(a)*9.5,az_+math.sin(a)*9.5,a,True)
npc('talk',ax_,az_,0.0)
# ================= RESSOURCES ET CAMPS =================
def scatter(path,cx,cz,n,rad,solid=False,minr=2.6):
    k=0; tries=0
    while k<n and tries<n*40:
        tries+=1
        x=cx+random.uniform(-rad,rad); z=cz+random.uniform(-rad,rad)
        if walk(x,z) and free(x,z,minr) and road_dist(x,z)>1.5:
            put(path,x,z,random.random()*math.tau,solid); occ.append((x,z,minr)); k+=1
for (x,z,t) in [(-28,-14,1),(-20,30,1),(-56,-50,2),(30,-60,2)]: scatter('@res:wood:%d'%t,x,z,6,7)
for (x,z,t) in [(72,-6,1),(84,20,1),(-30,-80,2),(84,-40,2)]: scatter('@res:ore:%d'%t,x,z,5,6)
for (x,z,t) in [(30,22,1),(-70,4,1),(-60,86,1),(-78,-20,2)]: scatter('@res:fiber:%d'%t,x,z,6,7)
camps=[]
for t,(zmin,zmax),want in [(1,(-10,104),9),(2,(-104,-10),9)]:
    tries=0
    while sum(1 for c in camps if c[2]==t)<want and tries<4000:
        tries+=1
        x=random.uniform(-100,100); z=random.uniform(zmin,zmax)
        if math.hypot(x-C[0],z-C[1])<52 or not walk(x,z) or not free(x,z,6) or road_dist(x,z)<5: continue
        if any(math.hypot(x-c[0],z-c[1])<17 for c in camps): continue
        if math.hypot(x-64,z-40)<22 or math.hypot(x+46,z-40)<22: continue
        hs=[hgt(x+u,z+v) for u in (-4,0,4) for v in (-4,0,4)]
        if max(hs)-min(hs)>2.0: continue
        camps.append((x,z,t)); put('@camp:%d'%t,x,z,0.0,False); occ.append((x,z,6))
print('camps',len(camps))
# ================= FORÊTS (arbres « terrain », dessinés en masse par le monde) =================
TREES=['Tree_1_A','Tree_1_B','Tree_1_C','Tree_2_A','Tree_2_C','Tree_1_A','Tree_4_A','Tree_4_B','Tree_4_A','Tree_1_C']
forest=[]
for cx,cz,rad,n in [[-60,-62,34,230],[36,-80,30,180],[-80,-20,20,80],[80,-50,18,60],[-82,60,12,34],[24,8,9,20],[-12,-70,14,44],[72,82,10,24],[-96,92,10,20],[96,90,10,20]]:
    k=0; tries=0
    while k<n and tries<n*25:
        tries+=1
        a=random.random()*math.tau; rr=rad*math.sqrt(random.random())
        x=cx+math.cos(a)*rr; z=cz+math.sin(a)*rr*0.85
        if walk(x,z) and road_dist(x,z)>2.5 and free(x,z,1.6):
            forest.append([round(x,2),round(z,2),round(random.uniform(0.85,1.35),2),round(random.random()*math.tau,2),random.choice(TREES)]); occ.append((x,z,1.7)); k+=1
json.dump(forest,open('/home/claude/vgodot/decor/forest_1.json','w'))
print('trees',len(forest))
json.dump(objs,open('/home/claude/vgodot/decor/map_1.json','w'))
json.dump({'objs':objs,'forests':[[-60,-62,34,200],[36,-80,30,160],[-80,-20,20,70],[80,-50,18,50],[-82,60,12,30],[24,8,9,18],[-12,-70,14,40],[72,82,10,22]],'lake':[LAKE[0][0],LAKE[0][1],LAKE[1]]},open('/tmp/claude-0/mapart/map1_full.json','w'))
from collections import Counter
print(len(objs), Counter(o[0].split(':')[0] for o in objs))
