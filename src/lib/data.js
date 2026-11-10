import { requireSupabase } from './supabase'

export async function fetchStores({ search = '', category = '' } = {}) {
  let q = requireSupabase().from('stores')
    .select('id,name,slug,description,logo_url,cover_url,category_id,category,city,neighborhood,address,whatsapp,latitude,longitude,status')
    .eq('status', 'approved').eq('is_active', true).order('created_at', { ascending: false })
  if (search) q = q.ilike('name', `%${search}%`)
  if (category) q = q.eq('category_id', category)
  const { data, error } = await q
  if (error) throw error
  return data ?? []
}

export async function fetchProducts({ search = '', storeId = null } = {}) {
  let q = requireSupabase().from('products')
    .select('id,store_id,name,description,price,promo_price,image_url,stock,is_active,is_featured,stores!inner(name,slug,whatsapp)')
    .eq('is_active', true).eq('stores.status', 'approved').order('created_at', { ascending: false })
  if (search) q = q.ilike('name', `%${search}%`)
  if (storeId) q = q.eq('store_id', storeId)
  const { data, error } = await q
  if (error) throw error
  return data ?? []
}

export async function saveFavorite(userId, targetType, targetId) {
  const db = requireSupabase()
  const { error } = await db.from('favorites').upsert(
    { user_id: userId, target_type: targetType, target_id: targetId },
    { onConflict: 'user_id,target_type,target_id' }
  )
  if (error) throw error
}
export async function removeFavorite(userId, targetType, targetId) {
  const { error } = await requireSupabase().from('favorites')
    .delete().eq('user_id', userId).eq('target_type', targetType).eq('target_id', targetId)
  if (error) throw error
}
