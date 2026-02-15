//para poder crear este archivo, hubo que poner el siguiente comando en la terminal: npx supabase functions new delete-user
// supabase/functions/delete-user/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    // Obtener el token del header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'No autorizado' }),
        { status: 401 }
      );
    }

    const token = authHeader.replace('Bearer ', '');
    
    // Crear cliente con el token del usuario
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    );

    // Establecer la sesión con el token
    await supabase.auth.setSession({
      access_token: token,
      refresh_token: ''
    });

    // Obtener el usuario
    const { data: { user } } = await supabase.auth.getUser();
    
    if (!user) {
      return new Response(
        JSON.stringify({ error: 'Usuario no encontrado' }),
        { status: 404 }
      );
    }

    // ELIMINAR EL USUARIO (esto requiere service role)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { error } = await supabaseAdmin.auth.admin.deleteUser(user.id);
    
    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500 }
      );
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200 }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    );
  }
});