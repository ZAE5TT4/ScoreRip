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

    override void Tick()
    {
        Super.Tick();

        double phase = (level.time % 28) / 28.0;
        double pulse = 0.5 + 0.5 * sin(phase * 360.0);
        Alpha = 0.20 + (0.42 * pulse);
        Scale = (0.82 + (0.26 * pulse), 0.82 + (0.26 * pulse));
        if (target == null || target.health <= 0)
        {
            if (glowLight != null)
            {
                glowLight.Destroy();
            }
            Destroy();
            return;
        }

        if (glowLight == null)
        {
            glowLight = Actor.Spawn("EXPEliteAuraLight", pos, ALLOW_REPLACE);
            if (glowLight != null)
            {
                glowLight.target = target;
            }
        }

        if (glowLight != null)
        {
            glowLight.SetOrigin(pos, false);
            glowLight.args[3] = 34 + int(18 * pulse);
        }
    }

    override void OnDestroy()
    {
        if (glowLight != null)
        {
            glowLight.Destroy();
            glowLight = null;
        }
        Super.OnDestroy();
    }

    Default
    {
        +NOINTERACTION;
        +NOBLOCKMAP;
        +NOSECTOR;
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

