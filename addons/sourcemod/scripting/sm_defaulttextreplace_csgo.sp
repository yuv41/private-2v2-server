#define PLUGIN_VERSION "1.0"
public Plugin:myinfo =
{
    name = "SM Chat Tag Replacer",
    author = "",
    description = "",
    version = PLUGIN_VERSION,
    url = ""
};
public OnPluginStart()
{
    // Just for games with Protobuf
    if(GetUserMessageType() == UM_Protobuf)
    {
        HookUserMessage(GetUserMessageId("TextMsg"), TextMsg, true);
    }
}

public Action:TextMsg(UserMsg:msg_id, Handle:pb, players[], playersNum, bool:reliable, bool:init)
{
    if(!reliable || PbReadInt(pb, "msg_dst") != 3)
    {
        return Plugin_Continue;
    }

    new String:buffer[256];
    PbReadString(pb, "params", buffer, sizeof(buffer), 0);

    if(StrContains(buffer, "[SM] ") == 0)
    {
        new Handle:pack;
        CreateDataTimer(0.0, new_output, pack, TIMER_FLAG_NO_MAPCHANGE);
        WritePackCell(pack, playersNum);
        for(new i = 0; i < playersNum; i++)
        {
            WritePackCell(pack, players[i]);
        }
        WritePackCell(pack, strlen(buffer));
        WritePackString(pack, buffer);
        ResetPack(pack);

        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action:new_output(Handle:timer, Handle:pack)
{
    new playersNum = ReadPackCell(pack);
    new players[playersNum];
    new player, players_count;

    for(new i = 0; i < playersNum; i++)
    {
        player = ReadPackCell(pack);

        if(IsClientInGame(player))
        {
            players[players_count++] = player;
        }
    }

    playersNum = players_count;

    if(playersNum < 1)
    {
        return;
    }

    new Handle:pb = StartMessage("TextMsg", players, playersNum, USERMSG_BLOCKHOOKS);
    PbSetInt(pb, "msg_dst", 3);

    new buffer_size = ReadPackCell(pack)+15;
    new String:buffer[buffer_size];
    ReadPackString(pack, buffer, buffer_size);

    // Just use one of below lines, not multiple...
    //Format(buffer, buffer_size, " \x01%s", buffer); // white
    //Format(buffer, buffer_size, " \x02%s", buffer); // red
    //Format(buffer, buffer_size, " \x03%s", buffer); //purple
    Format(buffer, buffer_size, " \x04[NewVision]\x01%s", buffer[4]); //purple [SM] prefix only
    //Format(buffer, buffer_size, " \x04%s", buffer); // green
    //Format(buffer, buffer_size, " \x05%s", buffer); // olive
    //Format(buffer, buffer_size, " \x06%s", buffer); // lime
    //Format(buffer, buffer_size, " \x07%s", buffer); // ligth red
    //Format(buffer, buffer_size, " \x08%s", buffer); // grey
    //Format(buffer, buffer_size, " \x09%s", buffer); // yellow
    //Format(buffer, buffer_size, " \x0202 \x0303 \x0404 \x0505 \x0606 \x0707 \x0808 \x0909");
    //PrintToServer("new %s", buffer);

    PbAddString(pb, "params", buffer);
    PbAddString(pb, "params", NULL_STRING);
    PbAddString(pb, "params", NULL_STRING);
    PbAddString(pb, "params", NULL_STRING);
    PbAddString(pb, "params", NULL_STRING);
    EndMessage();

} 