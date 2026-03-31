class EXPEliteStar : Actor
{
    private int birthTic;
    private int lifetime;

    override void BeginPlay()
    {
        Super.BeginPlay();
        birthTic = level.time;
        lifetime = 45 + Random(0, 20);
        double ang = Random(0, 359);
        double dist = 12.0 + Random(0, 20);
        vel.x = cos(ang) * 0.18;
        vel.y = sin(ang) * 0.18;
        vel.z = 0.55 + FRandom(0.0, 0.4);
        Scale = (0.34 + FRandom(0.0, 0.18), 0.34 + FRandom(0.0, 0.18));
    }

    override void Tick()
    {
        Super.Tick();
        int age = level.time - birthTic;
        if (age >= lifetime)
        {
            Destroy();
            return;
        }
        double t = double(age) / double(lifetime);
        double fade = t < 0.2 ? (t / 0.2) : (1.0 - (t - 0.2) / 0.8);
        if (fade < 0.0) { fade = 0.0; }
        Alpha = fade * 0.85;
        double sc = (0.22 + FRandom(0.0, 0.05)) * (1.0 - t * 0.7);
        if (sc < 0.02) { sc = 0.02; }
        Scale = (sc, sc);
        vel.z *= 0.97;
        vel.x *= 0.96;
        vel.y *= 0.96;
    }

    Default
    {
        +NOINTERACTION;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOTELEPORT;
        +THRUGHOST;
        +FORCEXYBILLBOARD;
        Alpha 0.0;
        Radius 4;
        Height 4;
        Scale 0.22;
        RenderStyle "Add";
    }
    States
    {
    Spawn:
        STLM ABCDDCBAABCDDCBAABCDDCBAABCDDCBAABCDDCBAABCDDCBA 5 Bright;
        Stop;
    }
}
class EXPEliteStarEmitter : Actor
{
    private int spawnCooldown;

    override void Tick()
    {
        Super.Tick();
        if (target == null || target.health <= 0)
        {
            Destroy();
            return;
        }
        SetOrigin(target.pos + (0, 0, 4), false);

        spawnCooldown--;
        if (spawnCooldown <= 0)
        {
            spawnCooldown = 16 + Random(0, 8);
            int count = Random(1, 2);
            for (int i = 0; i < count; i++)
            {
                double ang  = FRandom(0.0, 359.0);
                double dist = (target.radius * 1.05) + FRandom(8.0, 18.0);
                double offX = cos(ang) * dist;
                double offY = sin(ang) * dist;
                double offZ = 10.0 + FRandom(0.0, target.height * 0.50);
                Actor.Spawn('EXPEliteStar', target.pos + (offX, offY, offZ), ALLOW_REPLACE);
            }
        }
    }

    Default
    {
        +NOINTERACTION;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOTELEPORT;
        +THRUGHOST;
        Radius 1;
        Height 1;
    }
    States
    {
    Spawn:
        TNT1 AA 1;
        TNT1 AA 1;
        TNT1 AAA 1;
        Loop;
    }
}

class EXPEliteAuraLight : PointLightAdditive
{
    override void BeginPlay()
    {
        args[0] = 255;
        args[1] = 28;
        args[2] = 28;
        args[3] = 52;
        Super.BeginPlay();
    }

    Default
    {
        +DYNAMICLIGHT.ATTENUATE;
    }
}

class EXPEliteAura : Actor
{
    private Actor glowLight;
    private Actor starEmitter;

    override void Tick()
    {
        Super.Tick();

        double phase = (level.time % 28) / 28.0;
        double pulse = 0.5 + 0.5 * sin(phase * 360.0);
        Alpha = 0.20 + (0.42 * pulse);
        Scale = (0.82 + (0.26 * pulse), 0.82 + (0.26 * pulse));
        if (target == null || target.health <= 0)
        {
            if (glowLight != null) { glowLight.Destroy(); }
            if (starEmitter != null) { starEmitter.Destroy(); }
            Destroy();
            return;
        }

        if (glowLight == null)
        {
            glowLight = Actor.Spawn('EXPEliteAuraLight', pos, ALLOW_REPLACE);
            if (glowLight != null) { glowLight.target = target; }
        }

        if (starEmitter == null)
        {
            starEmitter = Actor.Spawn('EXPEliteStarEmitter', pos, ALLOW_REPLACE);
            if (starEmitter != null) { starEmitter.target = target; }
        }

        if (glowLight != null)
        {
            glowLight.SetOrigin(pos, false);
            glowLight.args[3] = 34 + int(18 * pulse);
        }
    }

    override void OnDestroy()
    {
        if (glowLight != null) { glowLight.Destroy(); glowLight = null; }
        if (starEmitter != null) { starEmitter.Destroy(); starEmitter = null; }
        Super.OnDestroy();
    }

    Default
    {
        +NOINTERACTION;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOTELEPORT;
        +THRUGHOST;
        +FORCEXYBILLBOARD;
        Alpha 0.45;
        Radius 10;
        Height 10;
        Scale 1.0;
        RenderStyle "Add";
    }
    States
    {
    Spawn:
        RESV A 1 Bright;
        Loop;
    }
}


