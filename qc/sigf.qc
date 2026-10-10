// Fallout 4 Takeover: Quake turned into the wasteland.
//  - Deathclaws, Super Mutants, Mr. Handy robots and Radroaches replace the dungeon monsters.
//  - Every kill drops bottle caps (and sometimes a Stimpak or a Nuka-Cola), gives XP, and a level up
//    shows the Vault Kid with a perk.
//  - The rocket launcher is the Fat Man: a mini nuke with a mushroom cloud and lingering radiation.
//  - Big kills trigger a V.A.T.S. slow-motion moment. A green wasteland haze covers the whole map.

.float sigf_caps;
.float sigf_xp;
.float sigf_level;
.float fo_kills;
.float sigf_t;
.float sigf_kind;
.float sigf_die;

float sigf_vats_until;

// ---------- helpers ----------
entity() sigf_player =
{
    return find(world, classname, "player");
};

void(entity p) sigf_status =
{
    sprint(p, "CAPS ");
    sprint(p, ftos(p.sigf_caps));
    sprint(p, "   LVL ");
    sprint(p, ftos(p.sigf_level));
    sprint(p, "   XP ");
    sprint(p, ftos(p.sigf_xp));
    sprint(p, "/");
    sprint(p, ftos(p.sigf_level * 60));
    sprint(p, "\n");
};

void(vector org) sigf_boom =
{
    WriteByte(MSG_BROADCAST, SVC_TEMPENTITY);
    WriteByte(MSG_BROADCAST, TE_EXPLOSION);
    WriteCoord(MSG_BROADCAST, org_x);
    WriteCoord(MSG_BROADCAST, org_y);
    WriteCoord(MSG_BROADCAST, org_z);
};

// the green wasteland haze
void() sigf_player_spawn =
{
    stuffcmd(self, "fog 0.05 0.55 0.55 0.25\n");
    stuffcmd(self, "r_wateralpha 1\n");
};

// ---------- loot: caps, stimpaks, Nuka-Cola ----------
void() sigf_pickup_touch =
{
    if (other.classname != "player")
        return;
    if (self.sigf_kind == 1)
    {
        other.sigf_caps = other.sigf_caps + self.sigf_t;
        sound(other, CHAN_ITEM, "sigf/caps.wav", 1, ATTN_NORM);
        sprint(other, "Bottle caps +");
        sprint(other, ftos(self.sigf_t));
        sprint(other, "\n");
        sigf_status(other);
    }
    else if (self.sigf_kind == 2)
    {
        if (!T_Heal(other, 25, 0))
            return;
        sound(other, CHAN_ITEM, "weapons/pkup.wav", 1, ATTN_NORM);
        sprint(other, "Stimpak used: +25 health\n");
    }
    else
    {
        T_Heal(other, 15, 0);
        other.items = other.items | IT_QUAD;
        other.super_time = 1;
        other.super_damage_finished = time + 10;
        sound(other, CHAN_ITEM, "sigf/caps.wav", 1, ATTN_NORM);
        centerprint(other, "Nuka-Cola Quantum!\nDouble damage for 10 seconds");
    }
    stuffcmd(other, "bf\n");
    remove(self);
};

// the pickup drifts toward the player when close (a loot magnet)
void() sigf_pickup_think =
{
    local entity p;
    p = sigf_player();
    if (p && p.health > 0 && vlen(p.origin - self.origin) < 220)
    {
        self.movetype = MOVETYPE_FLY;
        self.velocity = normalize(p.origin - self.origin) * 380;
    }
    if (time > self.sigf_die)
    {
        remove(self);
        return;
    }
    self.nextthink = time + 0.1;
};

void(vector org, float kind, float amount) sigf_drop =
{
    local entity o;
    o = spawn();
    o.classname = "sigf_pickup";
    o.movetype = MOVETYPE_TOSS;
    o.solid = SOLID_TRIGGER;
    o.sigf_kind = kind;
    o.sigf_t = amount;
    if (kind == 1)
    {
        setmodel(o, "progs/sigf_cap.spr");
        setsize(o, '-14 -14 -10', '14 14 10');
    }
    else if (kind == 2)
    {
        setmodel(o, "progs/sigf_stim.spr");
        setsize(o, '-16 -16 -14', '16 16 14');
    }
    else
    {
        setmodel(o, "progs/sigf_nuka.spr");
        setsize(o, '-14 -14 -20', '14 14 20');
        o.effects = EF_DIMLIGHT;
    }
    setorigin(o, org + '0 0 20');
    o.velocity_x = crandom() * 140;
    o.velocity_y = crandom() * 140;
    o.velocity_z = 220 + random() * 120;
    o.touch = sigf_pickup_touch;
    o.think = sigf_pickup_think;
    o.nextthink = time + 0.8;
    o.sigf_die = time + 40;
};

// ---------- level up: the Vault Kid pops up and gives a perk ----------
void() sigf_vault_think =
{
    remove(self);
};

void(entity p) sigf_vault_show =
{
    local entity v;
    makevectors(p.v_angle);
    v = spawn();
    v.classname = "sigf_vault";
    v.movetype = MOVETYPE_NOCLIP;
    v.solid = SOLID_NOT;
    setmodel(v, "progs/sigf_vault.spr");
    setsize(v, '0 0 0', '0 0 0');
    setorigin(v, p.origin + v_forward * 130 + v_right * 55 + '0 0 -20');
    v.velocity = '0 0 25';
    v.effects = EF_DIMLIGHT;
    v.think = sigf_vault_think;
    v.nextthink = time + 3;
};

void(entity p) sigf_levelup =
{
    local float r;
    p.sigf_level = p.sigf_level + 1;
    p.sigf_xp = 0;
    T_Heal(p, 100, 0);
    p.armorvalue = 100;
    p.armortype = 0.6;
    p.items = (p.items - (p.items & (IT_ARMOR1 | IT_ARMOR2 | IT_ARMOR3))) | IT_ARMOR2;
    p.items = p.items | IT_QUAD;
    p.super_time = 1;
    p.super_damage_finished = time + 6;
    r = random();
    if (r < 0.25)
        centerprint(p, "LEVEL UP!\nPerk: Toughness\nArmor restored");
    else if (r < 0.5)
        centerprint(p, "LEVEL UP!\nPerk: Nerd Rage\nDouble damage");
    else if (r < 0.75)
        centerprint(p, "LEVEL UP!\nPerk: Lone Wanderer\nHealth restored");
    else
        centerprint(p, "LEVEL UP!\nPerk: Action Boy\nGo get them");
    sound(p, CHAN_VOICE, "sigf/levelup.wav", 1, ATTN_NONE);
    stuffcmd(p, "bf\n");
    sigf_vault_show(p);
};

// ---------- V.A.T.S.: slow motion on big kills ----------
void() sigf_vats_end =
{
    cvar_set("host_timescale", "1");
    remove(self);
};

void(entity p) sigf_vats =
{
    local entity t;
    if (time < sigf_vats_until)
        return;
    sigf_vats_until = time + 6;
    cvar_set("host_timescale", "0.3");
    centerprint(p, "V.A.T.S.\nCritical hit!");
    stuffcmd(p, "bf\n");
    t = spawn();
    t.classname = "sigf_vatstimer";
    t.think = sigf_vats_end;
    t.nextthink = time + 0.5;
};

// ---------- the Fat Man: a mini nuke ----------
void() sigf_mush_think =
{
    if (self.frame < 3)
    {
        self.frame = self.frame + 1;
        self.nextthink = time + 0.18;
        return;
    }
    self.velocity = '0 0 14';
    self.think = SUB_Remove;
    self.nextthink = time + 2.2;
};

void() sigf_rad_think =
{
    local entity m;
    local vector o;
    local float i;
    if (time > self.sigf_t)
    {
        remove(self);
        return;
    }
    i = 0;
    while (i < 10)
    {
        o = self.origin + '0 0 8';
        o_x = o_x + crandom() * 150;
        o_y = o_y + crandom() * 150;
        o_z = o_z + random() * 60;
        particle(o, '0 0 6', 48, 20);
        i = i + 1;
    }
    sound(self, CHAN_AUTO, "sigf/geiger.wav", 0.7, ATTN_NORM);
    m = findradius(self.origin, 190);
    while (m)
    {
        if ((m.flags & FL_MONSTER) && m.health > 0)
        {
            T_Damage(m, self, self.owner, 4);
            particle(m.origin, '0 0 10', 48, 10);
        }
        m = m.chain;
    }
    self.nextthink = time + 0.4;
};

void(vector org) sigf_mushroom =
{
    local entity m;
    local float z;
    m = spawn();
    m.classname = "sigf_mushroom";
    m.movetype = MOVETYPE_NOCLIP;
    m.solid = SOLID_NOT;
    setmodel(m, "progs/sigf_mush.spr");
    setsize(m, '0 0 0', '0 0 0');
    setorigin(m, org);
    m.frame = 0;
    m.effects = EF_BRIGHTLIGHT;
    m.think = sigf_mush_think;
    m.nextthink = time + 0.18;
    z = 0;
    while (z < 120)
    {
        particle(org + '0 0 1' * z, '0 0 14', 232, 60);
        z = z + 30;
    }
};

void() sigf_nuke_touch =
{
    local entity r;
    local vector org;
    if (other == self.owner)
        return;
    if (pointcontents(self.origin) == CONTENT_SKY)
    {
        remove(self);
        return;
    }
    org = self.origin - normalize(self.velocity) * 8;
    T_RadiusDamage(self, self.owner, 220, self.owner);
    sigf_boom(org);
    sigf_boom(org + '60 0 30');
    sigf_boom(org + '-40 50 60');
    sigf_boom(org + '0 -60 90');
    sound(self, CHAN_WEAPON, "sigf/nukeboom.wav", 1, ATTN_NONE);
    sigf_mushroom(org);
    particle(org, '0 0 20', 48, 255);
    particle(org, '0 0 -20', 232, 255);
    stuffcmd(self.owner, "bf\n");
    stuffcmd(self.owner, "bf\n");
    r = spawn();
    r.classname = "sigf_radiation";
    r.owner = self.owner;
    setorigin(r, org);
    r.sigf_t = time + 8;
    r.think = sigf_rad_think;
    r.nextthink = time + 0.4;
    remove(self);
};

void() sigf_nuke_think =
{
    particle(self.origin, '0 0 0', 8, 6);
    particle(self.origin, '0 0 8', 232, 10);
    if (time > self.sigf_t)
    {
        remove(self);
        return;
    }
    self.nextthink = time + 0.04;
};

// replaces the vanilla rocket (called from W_FireRocket)
void() sigf_fire_nuke =
{
    local entity m;
    sound(self, CHAN_WEAPON, "weapons/sgun1.wav", 1, ATTN_NORM);
    self.punchangle_x = -5;
    makevectors(self.v_angle);
    m = spawn();
    m.owner = self;
    m.classname = "sigf_nuke";
    m.movetype = MOVETYPE_FLYMISSILE;
    m.solid = SOLID_BBOX;
    setmodel(m, "progs/sigf_nuke.mdl");
    setsize(m, '0 0 0', '0 0 0');
    setorigin(m, self.origin + v_forward * 12 + '0 0 14');
    m.velocity = aim(self, 1000) * 900;
    m.angles = vectoangles(m.velocity);
    m.effects = EF_DIMLIGHT;
    m.touch = sigf_nuke_touch;
    m.sigf_t = time + 5;
    m.think = sigf_nuke_think;
    m.nextthink = time + 0.04;
};

// ---------- the Deathclaw ----------
void() dc_stand1 = [0, dc_stand2] { ai_stand(); };
void() dc_stand2 = [1, dc_stand1] { ai_stand(); };

void() dc_walk1 = [2, dc_walk2] { ai_walk(8); };
void() dc_walk2 = [3, dc_walk3] { ai_walk(8); };
void() dc_walk3 = [4, dc_walk4] { ai_walk(8); };
void() dc_walk4 = [5, dc_walk1] { ai_walk(8); };

void() dc_run1 = [2, dc_run2] { ai_run(20); };
void() dc_run2 = [3, dc_run3] { ai_run(20); };
void() dc_run3 = [4, dc_run4] { ai_run(20); };
void() dc_run4 = [5, dc_run1] { ai_run(20); };

void() dc_swipe =
{
    local vector delta;
    ai_face();
    walkmove(self.ideal_yaw, 10);
    delta = self.enemy.origin - self.origin;
    if (vlen(delta) > 120)
        return;
    if (!CanDamage(self.enemy, self))
        return;
    sound(self, CHAN_WEAPON, "demon/dhit2.wav", 1, ATTN_NORM);
    T_Damage(self.enemy, self, self, 25 + 10 * random());
    makevectors(self.angles);
    SpawnMeatSpray(self.origin + v_forward * 24, v_right * (random() - 0.5) * 300);
};

void() dc_melee1 = [6, dc_melee2] { ai_face(); sound(self, CHAN_VOICE, "sigf/claw.wav", 1, ATTN_NORM); };
void() dc_melee2 = [7, dc_melee3] { ai_charge(6); };
void() dc_melee3 = [8, dc_melee4] { dc_swipe(); };
void() dc_melee4 = [9, dc_run1] { ai_charge(4); };

void() dc_leap_touch =
{
    if (self.health <= 0)
        return;
    if (other.takedamage && vlen(self.velocity) > 250)
    {
        sound(self, CHAN_WEAPON, "demon/dhit2.wav", 1, ATTN_NORM);
        T_Damage(other, self, self, 35 + 10 * random());
    }
    self.touch = SUB_Null;
};

void() dc_leap1 = [6, dc_leap2] { ai_face(); sound(self, CHAN_VOICE, "sigf/claw.wav", 1, ATTN_NORM); };
void() dc_leap2 = [7, dc_leap3] { ai_face(); };
void() dc_leap3 = [8, dc_leap4]
{
    ai_face();
    self.touch = dc_leap_touch;
    makevectors(self.angles);
    self.origin_z = self.origin_z + 1;
    self.velocity = v_forward * 560 + '0 0 230';
    self.flags = self.flags - (self.flags & FL_ONGROUND);
};
void() dc_leap4 = [9, dc_leap5] {};
void() dc_leap5 = [9, dc_leap6] {};
void() dc_leap6 = [9, dc_leap7] {};
void() dc_leap7 = [9, dc_leap8] {};
void() dc_leap8 = [9, dc_run1] { self.touch = SUB_Null; };

void() dc_pain1 = [10, dc_pain2] {};
void() dc_pain2 = [11, dc_run1] {};

void(entity attacker, float damage) dc_pain =
{
    if (self.touch == dc_leap_touch)
        return;
    if (self.pain_finished > time)
        return;
    self.pain_finished = time + 1;
    sound(self, CHAN_VOICE, "demon/dpain1.wav", 1, ATTN_NORM);
    if ((random() * 120) > damage)
        return;
    dc_pain1();
};

void() dc_die1 = [12, dc_die2] { sound(self, CHAN_VOICE, "demon/ddeath.wav", 1, ATTN_NORM); };
void() dc_die2 = [13, dc_die3] {};
void() dc_die3 = [14, dc_die4] { self.solid = SOLID_NOT; };
void() dc_die4 = [15, dc_die5] {};
void() dc_die5 = [16, dc_die5] {};

void() dc_die =
{
    if (self.health < -80)
    {
        sound(self, CHAN_VOICE, "player/udeath.wav", 1, ATTN_NORM);
        ThrowGib("progs/gib1.mdl", self.health);
        ThrowGib("progs/gib2.mdl", self.health);
        ThrowGib("progs/gib3.mdl", self.health);
        ThrowHead("progs/h_demon.mdl", self.health);
        return;
    }
    dc_die1();
};

void() monster_sigf_deathclaw =
{
    if (deathmatch)
    {
        remove(self);
        return;
    }
    precache_model("progs/sigf_deathclaw.mdl");
    precache_model("progs/h_demon.mdl");
    precache_sound("sigf/claw.wav");
    precache_sound("demon/dhit2.wav");
    precache_sound("demon/dpain1.wav");
    precache_sound("demon/ddeath.wav");
    self.solid = SOLID_SLIDEBOX;
    self.movetype = MOVETYPE_STEP;
    setmodel(self, "progs/sigf_deathclaw.mdl");
    setsize(self, '-32 -32 -24', '32 32 64');
    self.health = 250;
    self.th_stand = dc_stand1;
    self.th_walk = dc_walk1;
    self.th_run = dc_run1;
    self.th_melee = dc_melee1;
    self.th_missile = dc_leap1;
    self.th_pain = dc_pain;
    self.th_die = dc_die;
    self.sigf_kind = 9;              // a wasteland monster
    walkmonster_start();
};

// ---------- the Super Mutant ----------
void() sm_stand1 = [0, sm_stand2] { ai_stand(); };
void() sm_stand2 = [1, sm_stand1] { ai_stand(); };

void() sm_walk1 = [2, sm_walk2] { ai_walk(5); };
void() sm_walk2 = [3, sm_walk3] { ai_walk(5); };
void() sm_walk3 = [4, sm_walk4] { ai_walk(5); };
void() sm_walk4 = [5, sm_walk1] { ai_walk(5); };

void() sm_run1 = [2, sm_run2] { ai_run(12); };
void() sm_run2 = [3, sm_run3] { ai_run(12); };
void() sm_run3 = [4, sm_run4] { ai_run(12); };
void() sm_run4 = [5, sm_run1] { ai_run(12); };

void() sm_hammer =
{
    local vector delta;
    ai_face();
    delta = self.enemy.origin - self.origin;
    if (vlen(delta) > 110)
        return;
    if (!CanDamage(self.enemy, self))
        return;
    sound(self, CHAN_WEAPON, "weapons/ax1.wav", 1, ATTN_NORM);
    T_Damage(self.enemy, self, self, 25 + 10 * random());
    makevectors(self.angles);
    SpawnMeatSpray(self.origin + v_forward * 24, v_right * (random() - 0.5) * 300);
};

void() sm_melee1 = [6, sm_melee2] { ai_face(); sound(self, CHAN_VOICE, "sigf/mutant.wav", 1, ATTN_NORM); };
void() sm_melee2 = [7, sm_melee3] { ai_charge(4); };
void() sm_melee3 = [8, sm_melee4] { sm_hammer(); };
void() sm_melee4 = [9, sm_run1] { ai_charge(2); };

void() sm_throw1 = [6, sm_throw2] { ai_face(); sound(self, CHAN_VOICE, "sigf/mutant.wav", 1, ATTN_NORM); };
void() sm_throw2 = [7, sm_throw3] { ai_face(); };
void() sm_throw3 = [8, sm_throw4] { ai_face(); OgreFireGrenade(); };
void() sm_throw4 = [9, sm_run1] { ai_face(); };

void() sm_pain1 = [10, sm_pain2] {};
void() sm_pain2 = [11, sm_run1] {};

void(entity attacker, float damage) sm_pain =
{
    if (self.pain_finished > time)
        return;
    self.pain_finished = time + 1;
    sound(self, CHAN_VOICE, "ogre/ogpain1.wav", 1, ATTN_NORM);
    sm_pain1();
};

void() sm_die1 = [12, sm_die2] { sound(self, CHAN_VOICE, "ogre/ogdth.wav", 1, ATTN_NORM); };
void() sm_die2 = [13, sm_die3] {};
void() sm_die3 = [14, sm_die4] { self.solid = SOLID_NOT; };
void() sm_die4 = [15, sm_die5] {};
void() sm_die5 = [16, sm_die5] {};

void() sm_die =
{
    if (self.health < -40)
    {
        sound(self, CHAN_VOICE, "player/udeath.wav", 1, ATTN_NORM);
        ThrowHead("progs/h_ogre.mdl", self.health);
        ThrowGib("progs/gib3.mdl", self.health);
        ThrowGib("progs/gib3.mdl", self.health);
        ThrowGib("progs/gib3.mdl", self.health);
        return;
    }
    sm_die1();
};

void() monster_sigf_mutant =
{
    if (deathmatch)
    {
        remove(self);
        return;
    }
    precache_model("progs/sigf_mutant.mdl");
    precache_model("progs/h_ogre.mdl");
    precache_model("progs/grenade.mdl");
    precache_sound("sigf/mutant.wav");
    precache_sound("ogre/ogpain1.wav");
    precache_sound("ogre/ogdth.wav");
    precache_sound("weapons/ax1.wav");
    precache_sound("weapons/grenade.wav");
    precache_sound("weapons/bounce.wav");
    self.solid = SOLID_SLIDEBOX;
    self.movetype = MOVETYPE_STEP;
    setmodel(self, "progs/sigf_mutant.mdl");
    setsize(self, '-32 -32 -24', '32 32 64');
    self.health = 160;
    self.th_stand = sm_stand1;
    self.th_walk = sm_walk1;
    self.th_run = sm_run1;
    self.th_melee = sm_melee1;
    self.th_missile = sm_throw1;
    self.th_pain = sm_pain;
    self.th_die = sm_die;
    self.sigf_kind = 9;              // a wasteland monster
    walkmonster_start();
};

// ---------- Mr. Handy: a floating robot with a flamethrower and a buzzsaw ----------
void() mh_stand1 = [0, mh_stand2] { ai_stand(); };
void() mh_stand2 = [1, mh_stand1] { ai_stand(); };

void() mh_walk1 = [2, mh_walk2] { ai_walk(6); };
void() mh_walk2 = [3, mh_walk3] { ai_walk(6); };
void() mh_walk3 = [4, mh_walk4] { ai_walk(6); };
void() mh_walk4 = [5, mh_walk1] { ai_walk(6); };

void() mh_run1 = [2, mh_run2] { ai_run(12); };
void() mh_run2 = [3, mh_run3] { ai_run(12); };
void() mh_run3 = [4, mh_run4] { ai_run(12); };
void() mh_run4 = [5, mh_run1] { ai_run(12); };

void() sigf_blob_think =
{
    particle(self.origin, '0 0 6', 232, 8);
    remove(self);
};

void(vector org, vector dir) sigf_flame_blob =
{
    local entity b;
    b = spawn();
    b.classname = "sigf_flame";
    b.movetype = MOVETYPE_FLY;
    b.solid = SOLID_NOT;
    setmodel(b, "progs/lavaball.mdl");
    setsize(b, '0 0 0', '0 0 0');
    setorigin(b, org);
    b.velocity = dir * (380 + random() * 120) + '0 0 1' * (crandom() * 40);
    b.velocity_x = b.velocity_x + crandom() * 45;
    b.velocity_y = b.velocity_y + crandom() * 45;
    b.avelocity = '300 300 300';
    b.effects = EF_DIMLIGHT;
    b.think = sigf_blob_think;
    b.nextthink = time + 0.4 + random() * 0.2;
};

void() mh_flame =
{
    local vector org, dir;
    ai_charge(3);
    org = self.origin + '0 0 -4';
    dir = normalize(self.enemy.origin - org);
    self.effects = self.effects | EF_MUZZLEFLASH;
    sigf_flame_blob(org + dir * 26, dir);
    sigf_flame_blob(org + dir * 26, dir);
    sigf_flame_blob(org + dir * 26, dir);
    particle(org + dir * 60, dir * 8, 232, 30);
    if (vlen(self.enemy.origin - self.origin) < 280 && CanDamage(self.enemy, self))
    {
        T_Damage(self.enemy, self, self, 4);
        stuffcmd(self.enemy, "bf\n");
    }
};

void() mh_fire1 = [6, mh_fire2] { ai_face(); sound(self, CHAN_WEAPON, "sigf/flame.wav", 1, ATTN_NORM); };
void() mh_fire2 = [7, mh_fire3] { ai_face(); mh_flame(); };
void() mh_fire3 = [8, mh_fire4] { ai_face(); mh_flame(); };
void() mh_fire4 = [9, mh_fire5] { ai_face(); mh_flame(); };
void() mh_fire5 = [7, mh_fire6] { ai_face(); mh_flame(); };
void() mh_fire6 = [8, mh_fire7] { ai_face(); mh_flame(); };
void() mh_fire7 = [9, mh_fire8] { ai_face(); mh_flame(); };
void() mh_fire8 = [6, mh_run1] { ai_face(); mh_flame(); };

void() mh_saw =
{
    local vector delta;
    ai_face();
    delta = self.enemy.origin - self.origin;
    if (vlen(delta) > 100)
        return;
    if (!CanDamage(self.enemy, self))
        return;
    sound(self, CHAN_WEAPON, "weapons/tink1.wav", 1, ATTN_NORM);
    T_Damage(self.enemy, self, self, 10 + 6 * random());
    particle(self.enemy.origin, '0 0 40', 192, 30);
};

void() mh_melee1 = [6, mh_melee2] { ai_face(); sound(self, CHAN_VOICE, "sigf/handy.wav", 1, ATTN_NORM); };
void() mh_melee2 = [7, mh_melee3] { ai_charge(6); };
void() mh_melee3 = [8, mh_melee4] { mh_saw(); };
void() mh_melee4 = [9, mh_run1] { mh_saw(); };

void() mh_pain1 = [10, mh_pain2] {};
void() mh_pain2 = [11, mh_run1] {};

void(entity attacker, float damage) mh_pain =
{
    particle(self.origin, '0 0 40', 192, 40);
    sound(self, CHAN_VOICE, "weapons/ric1.wav", 1, ATTN_NORM);
    if (self.pain_finished > time)
        return;
    self.pain_finished = time + 1;
    mh_pain1();
};

void() mh_die1 = [12, mh_die2]
{
    self.velocity_x = -150 + 300 * random();
    self.velocity_y = -150 + 300 * random();
    self.velocity_z = 120;
    self.flags = self.flags - (self.flags & FL_FLY);
    self.flags = self.flags - (self.flags & FL_ONGROUND);
    self.movetype = MOVETYPE_TOSS;
    sound(self, CHAN_VOICE, "sigf/handy.wav", 1, ATTN_NORM);
    sigf_boom(self.origin);
    particle(self.origin, '0 0 60', 192, 120);
};
void() mh_die2 = [13, mh_die3] { self.effects = EF_DIMLIGHT; };
void() mh_die3 = [14, mh_die4] { self.solid = SOLID_NOT; };
void() mh_die4 = [15, mh_die5] { particle(self.origin, '0 0 20', 8, 30); };
void() mh_die5 = [16, mh_die5] { self.effects = 0; };

void() mh_die =
{
    mh_die1();
};

void() monster_sigf_handy =
{
    if (deathmatch)
    {
        remove(self);
        return;
    }
    precache_model("progs/sigf_handy.mdl");
    precache_model("progs/lavaball.mdl");
    precache_sound("sigf/handy.wav");
    precache_sound("sigf/flame.wav");
    precache_sound("weapons/tink1.wav");
    precache_sound("weapons/ric1.wav");
    self.solid = SOLID_SLIDEBOX;
    self.movetype = MOVETYPE_STEP;
    setmodel(self, "progs/sigf_handy.mdl");
    setsize(self, '-24 -24 -24', '24 24 24');
    self.health = 80;
    self.th_stand = mh_stand1;
    self.th_walk = mh_walk1;
    self.th_run = mh_run1;
    self.th_melee = mh_melee1;
    self.th_missile = mh_fire1;
    self.th_pain = mh_pain;
    self.th_die = mh_die;
    self.sigf_kind = 9;              // a wasteland monster
    flymonster_start();
};

// ---------- the Radroach: small, fast, comes in swarms ----------
void() rr_stand1 = [0, rr_stand2] { ai_stand(); };
void() rr_stand2 = [1, rr_stand1] { ai_stand(); };

void() rr_walk1 = [2, rr_walk2] { ai_walk(8); };
void() rr_walk2 = [3, rr_walk3] { ai_walk(8); };
void() rr_walk3 = [4, rr_walk4] { ai_walk(8); };
void() rr_walk4 = [5, rr_walk1] { ai_walk(8); };

void() rr_run1 = [2, rr_run2] { ai_run(22); };
void() rr_run2 = [3, rr_run3] { ai_run(22); };
void() rr_run3 = [4, rr_run4] { ai_run(22); };
void() rr_run4 = [5, rr_run1] { ai_run(22); };

void() rr_bite =
{
    ai_charge(10);
    if (!self.enemy)
        return;
    if (vlen(self.enemy.origin - self.origin) > 70)
        return;
    if (!CanDamage(self.enemy, self))
        return;
    sound(self, CHAN_WEAPON, "sigf/roach.wav", 1, ATTN_NORM);
    T_Damage(self.enemy, self, self, 5 + 5 * random());
};

void() rr_melee1 = [6, rr_melee2] { ai_charge(6); };
void() rr_melee2 = [7, rr_melee3] { ai_charge(8); rr_bite(); };
void() rr_melee3 = [8, rr_melee4] { ai_charge(8); };
void() rr_melee4 = [9, rr_run1] { ai_charge(6); rr_bite(); };

void() rr_pain1 = [10, rr_pain2] {};
void() rr_pain2 = [11, rr_run1] {};

void(entity attacker, float damage) rr_pain =
{
    particle(self.origin, '0 0 20', 48, 25);
    if (self.pain_finished > time)
        return;
    self.pain_finished = time + 0.6;
    sound(self, CHAN_VOICE, "sigf/roach.wav", 1, ATTN_NORM);
    rr_pain1();
};

void() rr_die1 = [12, rr_die2] { particle(self.origin, '0 0 40', 48, 60); sound(self, CHAN_VOICE, "sigf/roach.wav", 1, ATTN_NORM); };
void() rr_die2 = [13, rr_die3] {};
void() rr_die3 = [14, rr_die4] { self.solid = SOLID_NOT; };
void() rr_die4 = [15, rr_die5] {};
void() rr_die5 = [16, rr_die5] {};

void() rr_die =
{
    if (self.health < -20)
    {
        sound(self, CHAN_VOICE, "player/udeath.wav", 1, ATTN_NORM);
        particle(self.origin, '0 0 60', 48, 120);
        ThrowGib("progs/gib3.mdl", self.health);
        ThrowGib("progs/gib3.mdl", self.health);
        return;
    }
    rr_die1();
};

void() monster_sigf_roach =
{
    if (deathmatch)
    {
        remove(self);
        return;
    }
    precache_model("progs/sigf_roach.mdl");
    precache_sound("sigf/roach.wav");
    self.solid = SOLID_SLIDEBOX;
    self.movetype = MOVETYPE_STEP;
    setmodel(self, "progs/sigf_roach.mdl");
    setsize(self, '-20 -20 -24', '20 20 0');
    self.health = 30;
    self.th_stand = rr_stand1;
    self.th_walk = rr_walk1;
    self.th_run = rr_run1;
    self.th_melee = rr_melee1;
    self.th_pain = rr_pain;
    self.th_die = rr_die;
    self.sigf_kind = 9;              // a wasteland monster
    walkmonster_start();
};

// ---------- the takeover: dungeon monsters of the map become wasteland monsters ----------
// called from walkmonster_start / flymonster_start; returns TRUE when it replaced the monster
float() sigf_takeover =
{
    local string c;
    c = self.classname;
    if (c == "monster_ogre" || c == "monster_knight" || c == "monster_enforcer")
    {
        self.classname = "monster_sigf_mutant";
        monster_sigf_mutant();
        return TRUE;
    }
    if (c == "monster_demon1" || c == "monster_shambler" || c == "monster_hell_knight")
    {
        self.classname = "monster_sigf_deathclaw";
        monster_sigf_deathclaw();
        return TRUE;
    }
    if (c == "monster_wizard")
    {
        self.classname = "monster_sigf_handy";
        monster_sigf_handy();
        return TRUE;
    }
    if (c == "monster_dog" || c == "monster_tarbaby")
    {
        self.classname = "monster_sigf_roach";
        monster_sigf_roach();
        return TRUE;
    }
    return FALSE;
};

// ---------- the demo director: keeps the fight going in the courtyard (demo and intermission only) ----------
// a yaw that looks along the plateau (open air ahead, solid floor 130 and 260 units ahead): the player and the
// new monsters face it, so the fight happens on the plateau and not against a wall or over the pool
float() sigf_open_yaw =
{
    local float k, yaw, ok;
    k = 0;
    while (k < 24)
    {
        yaw = anglemod(300 + k * 15);
        makevectors('0 1 0' * yaw);
        ok = TRUE;
        traceline('416 1488 90', '416 1488 90' + v_forward * 380, TRUE, world);
        if (trace_fraction < 1)
            ok = FALSE;
        traceline('416 1488 90' + v_forward * 130, '416 1488 90' + v_forward * 130 - '0 0 300', TRUE, world);
        if (trace_endpos_z < 20 || trace_endpos_z > 70)
            ok = FALSE;
        traceline('416 1488 90' + v_forward * 260, '416 1488 90' + v_forward * 260 - '0 0 300', TRUE, world);
        if (trace_endpos_z < 20 || trace_endpos_z > 70)
            ok = FALSE;
        if (ok)
            return yaw;
        k = k + 1;
    }
    return 300;
};

// counts the living wasteland monsters near the player; the ones that got stuck far away are removed
float(entity p) sigf_count_wasteland =
{
    local entity m, nxt;
    local float n;
    n = 0;
    m = nextent(world);
    while (m)
    {
        nxt = nextent(m);
        if ((m.flags & FL_MONSTER) && m.health > 0 && m.sigf_kind == 9)
        {
            if (vlen(m.origin - p.origin) > 600)
                remove(m);
            else
                n = n + 1;
        }
        m = nxt;
    }
    return n;
};

void() sigf_director_think =
{
    local entity p, d;
    local float n, r;
    d = self;
    self.nextthink = time + 0.4;
    p = sigf_player();
    if (!p || p.health <= 0)
        return;
    // back to the courtyard when the explorer wandered off (it would walk into the building and the lava)
    makevectors('0 1 0' * p.v_angle_y);
    traceline(p.origin + '0 0 20', p.origin + '0 0 20' + v_forward * 230, TRUE, p);
    if (trace_fraction < 1 || vlen(p.origin - '416 1488 60') > 260 || fabs(p.origin_z - 60) > 90)
    {
        setorigin(p, '416 1488 60');
        p.v_angle_y = sigf_open_yaw() + crandom() * 25;
        p.angles_y = p.v_angle_y;
        p.fixangle = TRUE;
        p.velocity = '0 0 0';
    }
    if (time < self.sigf_t)
        return;
    self.sigf_t = time + 1.6;
    n = sigf_count_wasteland(p);
    if (n >= 4)
        return;
    if (n >= 2)
        p.weapon = IT_ROCKET_LAUNCHER;
    else
        p.weapon = IT_SUPER_NAILGUN;
    self = p;
    W_SetCurrentAmmo();
    self = d;
    r = random();
    if (r < 0.35)
        SIGF_SpawnAhead("monster_sigf_roach", monster_sigf_roach, 300 + random() * 100, crandom() * 120);
    else if (r < 0.6)
        SIGF_SpawnAhead("monster_sigf_mutant", monster_sigf_mutant, 350 + random() * 100, crandom() * 120);
    else if (r < 0.8)
        SIGF_SpawnAhead("monster_sigf_handy", monster_sigf_handy, 330 + random() * 100, crandom() * 120);
    else
        SIGF_SpawnAhead("monster_sigf_deathclaw", monster_sigf_deathclaw, 400 + random() * 100, crandom() * 100);
    if (random() < 0.5)
        SIGF_SpawnAhead("monster_sigf_roach", monster_sigf_roach, 320 + random() * 80, crandom() * 140);
};

void() sigf_start_director =
{
    local entity d;
    d = spawn();
    d.classname = "sigf_director";
    d.think = sigf_director_think;
    d.nextthink = time + 11;
};

// ---------- the three hooks ----------
void() SIGF_Precache =
{
    precache_model("progs/sigf_nuke.mdl");
    precache_model("progs/sigf_cap.spr");
    precache_model("progs/sigf_stim.spr");
    precache_model("progs/sigf_nuka.spr");
    precache_model("progs/sigf_vault.spr");
    precache_model("progs/sigf_mush.spr");
    precache_sound("items/damage2.wav");
    precache_sound("items/damage3.wav");
    precache_sound("sigf/caps.wav");
    precache_sound("sigf/levelup.wav");
    precache_sound("sigf/geiger.wav");
    precache_sound("sigf/nukeboom.wav");
    precache_sound("weapons/pkup.wav");
    precache_sound("weapons/sgun1.wav");
    SIGF_Preload("monster_sigf_deathclaw", monster_sigf_deathclaw);
    SIGF_Preload("monster_sigf_mutant", monster_sigf_mutant);
    SIGF_Preload("monster_sigf_handy", monster_sigf_handy);
    SIGF_Preload("monster_sigf_roach", monster_sigf_roach);
};

void(float wave) SIGF_DemoWave =
{
    if (wave == 0)
    {
        setorigin(self, '416 1488 60');          // the open courtyard of the map
        self.v_angle_y = sigf_open_yaw();
        self.angles_y = self.v_angle_y;
        self.fixangle = TRUE;
        self.items = self.items | IT_SUPER_SHOTGUN | IT_NAILGUN | IT_SUPER_NAILGUN | IT_ROCKET_LAUNCHER;
        self.weapon = IT_SUPER_NAILGUN;
        W_SetCurrentAmmo();
        sigf_player_spawn();
        centerprint(self, "WAR NEVER CHANGES\nFallout 4 Takeover");
        sigf_vault_show(self);
        sigf_start_director();
        SIGF_SpawnAhead("monster_sigf_mutant", monster_sigf_mutant, 330, -50);
        SIGF_SpawnAhead("monster_sigf_roach", monster_sigf_roach, 280, 60);
        SIGF_SpawnAhead("monster_sigf_roach", monster_sigf_roach, 300, 110);
        return;
    }
    if (wave == 1)
    {
        self.weapon = IT_ROCKET_LAUNCHER;
        W_SetCurrentAmmo();
        centerprint(self, "Fat Man loaded");
        SIGF_SpawnAhead("monster_sigf_deathclaw", monster_sigf_deathclaw, 420, 0);
        SIGF_SpawnAhead("monster_sigf_mutant", monster_sigf_mutant, 440, -70);
        SIGF_SpawnAhead("monster_sigf_roach", monster_sigf_roach, 400, 70);
        SIGF_SpawnAhead("monster_sigf_roach", monster_sigf_roach, 380, 40);
        return;
    }
    if (wave == 2)
    {
        self.weapon = IT_SUPER_NAILGUN;
        W_SetCurrentAmmo();
        SIGF_SpawnAhead("monster_sigf_handy", monster_sigf_handy, 330, 40);
        SIGF_SpawnAhead("monster_sigf_roach", monster_sigf_roach, 300, -80);
        return;
    }
};

void(entity targ, entity attacker) SIGF_OnKilled =
{
    local entity p;
    local float xp, caps, big;
    if (!(targ.flags & FL_MONSTER))
        return;
    p = sigf_player();
    if (!p)
        return;
    xp = 10;
    caps = 4 + floor(random() * 6);
    big = FALSE;
    if (targ.classname == "monster_sigf_deathclaw")
    {
        xp = 60;
        caps = 25 + floor(random() * 20);
        big = TRUE;
    }
    else if (targ.classname == "monster_sigf_mutant")
    {
        xp = 35;
        caps = 15 + floor(random() * 10);
        big = TRUE;
    }
    else if (targ.classname == "monster_sigf_handy")
        xp = 25;
    else if (targ.classname == "monster_sigf_roach")
    {
        xp = 8;
        caps = 2 + floor(random() * 3);
    }
    sigf_drop(targ.origin, 1, caps);
    if (big)
        sigf_drop(targ.origin, 1, caps);
    if (random() < 0.4)
        sigf_drop(targ.origin, 2, 0);
    if (random() < 0.15)
        sigf_drop(targ.origin, 3, 0);
    p.sigf_xp = p.sigf_xp + xp;
    p.fo_kills = p.fo_kills + 1;
    if (p.sigf_level < 1)
        p.sigf_level = 1;
    if (p.sigf_xp >= p.sigf_level * 60)
        sigf_levelup(p);
    else if (big)
        sigf_vats(p);
};
